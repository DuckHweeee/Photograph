import XCTest
@testable import photograph

final class FirestoreRESTTests: XCTestCase {
    // 2026-09-25T04:05:06Z
    private let baseEpoch: TimeInterval = 1_790_309_106

    // MARK: Timestamps

    func testParsesNanosecondTimestamp() throws {
        let date = try XCTUnwrap(FirestoreREST.parseTimestamp("2026-09-25T04:05:06.123456789Z"))
        XCTAssertEqual(date.timeIntervalSince1970, baseEpoch + 0.123, accuracy: 0.0005)
    }

    func testParsesTimestampWithoutFraction() throws {
        let date = try XCTUnwrap(FirestoreREST.parseTimestamp("2026-09-25T04:05:06Z"))
        XCTAssertEqual(date.timeIntervalSince1970, baseEpoch, accuracy: 0.0005)
    }

    func testParsesShortFractionAndOffset() throws {
        let date = try XCTUnwrap(FirestoreREST.parseTimestamp("2026-09-25T11:05:06.5+07:00"))
        XCTAssertEqual(date.timeIntervalSince1970, baseEpoch + 0.5, accuracy: 0.0005)
    }

    func testRejectsGarbageTimestamp() {
        XCTAssertNil(FirestoreREST.parseTimestamp("yesterday"))
    }

    // MARK: runQuery

    func testPicksLatestMomentFromPartnerAndSkipsOwn() throws {
        let json = """
        [
          {"document": {"name": "projects/p/databases/(default)/documents/couples/spike/moments/mine1",
                        "fields": {"authorUid": {"stringValue": "me"},
                                   "type": {"stringValue": "note"},
                                   "text": {"stringValue": "của tớ"},
                                   "createdAt": {"timestampValue": "2026-09-25T04:05:07.5Z"}}},
           "readTime": "2026-09-25T04:06:00Z"},
          {"document": {"name": "projects/p/databases/(default)/documents/couples/spike/moments/theirs1",
                        "fields": {"authorUid": {"stringValue": "partner"},
                                   "type": {"stringValue": "photo"},
                                   "createdAt": {"timestampValue": "2026-09-25T04:05:06.123456Z"}}},
           "readTime": "2026-09-25T04:06:00Z"}
        ]
        """
        let moment = try XCTUnwrap(FirestoreREST.parseLatestPartnerMoment(
            fromRunQueryResponse: Data(json.utf8), excludingAuthor: "me"
        ))
        XCTAssertEqual(moment.id, "theirs1")
        XCTAssertEqual(moment.authorUid, "partner")
        XCTAssertEqual(moment.kind, .photo)
        XCTAssertNil(moment.text)
        XCTAssertEqual(moment.createdAt.timeIntervalSince1970, baseEpoch + 0.123, accuracy: 0.0005)
    }

    func testEmptyCollectionReturnsNil() throws {
        let json = #"[{"readTime": "2026-09-25T04:06:00Z"}]"#
        XCTAssertNil(try FirestoreREST.parseLatestPartnerMoment(
            fromRunQueryResponse: Data(json.utf8), excludingAuthor: "me"
        ))
    }

    func testOnlyOwnMomentsReturnsNil() throws {
        let json = """
        [{"document": {"name": "x/moments/mine1",
                       "fields": {"authorUid": {"stringValue": "me"},
                                  "type": {"stringValue": "note"},
                                  "createdAt": {"timestampValue": "2026-09-25T04:05:06Z"}}}}]
        """
        XCTAssertNil(try FirestoreREST.parseLatestPartnerMoment(
            fromRunQueryResponse: Data(json.utf8), excludingAuthor: "me"
        ))
    }

    func testSkipsDocumentWithUnknownType() throws {
        let json = """
        [{"document": {"name": "x/moments/weird",
                       "fields": {"authorUid": {"stringValue": "partner"},
                                  "type": {"stringValue": "video"},
                                  "createdAt": {"timestampValue": "2026-09-25T04:05:06Z"}}}}]
        """
        XCTAssertNil(try FirestoreREST.parseLatestPartnerMoment(
            fromRunQueryResponse: Data(json.utf8), excludingAuthor: "me"
        ))
    }

    func testMalformedResponseThrows() {
        XCTAssertThrowsError(try FirestoreREST.parseLatestPartnerMoment(
            fromRunQueryResponse: Data(#"{"error": "nope"}"#.utf8), excludingAuthor: "me"
        ))
    }

    func testQueryIsValidJSONAndSkipsImageBytes() throws {
        let query = FirestoreREST.latestMomentsQuery()
        XCTAssertTrue(JSONSerialization.isValidJSONObject(query))
        let body = String(decoding: try JSONSerialization.data(withJSONObject: query), as: UTF8.self)
        XCTAssertFalse(body.contains("imageData"))
        XCTAssertTrue(body.contains("DESCENDING"))
    }

    func testRunQueryURLKeepsColon() {
        let url = FirestoreREST.documentURL(Self.session, path: "couples/spike:runQuery")
        XCTAssertEqual(
            url.absoluteString,
            "https://firestore.googleapis.com/v1/projects/demo-project/databases/(default)/documents/couples/spike:runQuery"
        )
    }

    // MARK: Image document

    func testParsesImageBytes() throws {
        let json = #"{"name": "x/moments/theirs1", "fields": {"imageData": {"bytesValue": "AQID"}}}"#
        XCTAssertEqual(try FirestoreREST.parseImageData(fromDocument: Data(json.utf8)), Data([1, 2, 3]))
    }

    func testNoteDocumentHasNoImage() throws {
        // With mask.fieldPaths=imageData, a note comes back without a "fields" key.
        let json = #"{"name": "x/moments/note1"}"#
        XCTAssertNil(try FirestoreREST.parseImageData(fromDocument: Data(json.utf8)))
    }

    // MARK: Token exchange

    func testFormBodyEscapesPlusAndSlash() {
        let body = String(decoding: FirestoreREST.formBody(["refresh_token": "a+b/c=", "grant_type": "refresh_token"]), as: UTF8.self)
        XCTAssertEqual(body, "grant_type=refresh_token&refresh_token=a%2Bb%2Fc%3D")
    }

    func testAppliesTokenResponse() throws {
        let now = Date(timeIntervalSince1970: baseEpoch)
        let json = #"{"id_token": "id-2", "refresh_token": "refresh-2", "expires_in": "3600", "token_type": "Bearer", "user_id": "me"}"#
        let updated = try FirestoreREST.applyTokenResponse(Data(json.utf8), to: Self.session, now: now)
        XCTAssertEqual(updated.idToken, "id-2")
        XCTAssertEqual(updated.refreshToken, "refresh-2")
        XCTAssertEqual(updated.idTokenExpiry, now.addingTimeInterval(3600))
        XCTAssertTrue(updated.hasValidIDToken(at: now))
        XCTAssertFalse(updated.hasValidIDToken(at: now.addingTimeInterval(3590)))
    }

    func testSessionWithoutTokenIsNotValid() {
        XCTAssertFalse(Self.session.hasValidIDToken())
    }

    func testMalformedTokenResponseThrows() {
        XCTAssertThrowsError(try FirestoreREST.applyTokenResponse(
            Data(#"{"error": {"message": "TOKEN_EXPIRED"}}"#.utf8), to: Self.session, now: Date()
        ))
    }

    private static let session = SharedSession(
        uid: "me",
        coupleId: "spike",
        apiKey: "key",
        projectId: "demo-project",
        bundleId: "hwee.photograph",
        refreshToken: "refresh-1",
        idToken: nil,
        idTokenExpiry: nil
    )
}
