// Rules tests for the week-1 spike (couples/spike/moments).
// Run: cd firestore-tests && npm install && npm test   (needs Java for the emulator)
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Bytes,
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-photograph',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const moments = (db) => collection(db, 'couples/spike/moments');
const bytes = (n) => Bytes.fromUint8Array(new Uint8Array(n));

describe('couples/spike/moments', () => {
  test('signed-in user can send a note', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertSucceeds(addDoc(moments(db), {
      authorUid: 'alice', type: 'note', text: 'nhớ cậu quá 🥺', createdAt: serverTimestamp(),
    }));
  });

  test('signed-in user can send a 200 KB photo with caption', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertSucceeds(addDoc(moments(db), {
      authorUid: 'alice', type: 'photo', imageData: bytes(200 * 1024), text: 'hôm nay', createdAt: serverTimestamp(),
    }));
  });

  test('photo over 200 KB is rejected', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(addDoc(moments(db), {
      authorUid: 'alice', type: 'photo', imageData: bytes(200 * 1024 + 1), createdAt: serverTimestamp(),
    }));
  });

  test('cannot send as someone else', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(addDoc(moments(db), {
      authorUid: 'bob', type: 'note', text: 'giả mạo', createdAt: serverTimestamp(),
    }));
  });

  test('createdAt must be the server time', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(addDoc(moments(db), {
      authorUid: 'alice', type: 'note', text: 'hi', createdAt: new Date('2020-01-01'),
    }));
  });

  test('empty note and note with image are rejected', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(addDoc(moments(db), {
      authorUid: 'alice', type: 'note', text: '', createdAt: serverTimestamp(),
    }));
    await assertFails(addDoc(moments(db), {
      authorUid: 'alice', type: 'note', text: 'hi', imageData: bytes(10), createdAt: serverTimestamp(),
    }));
  });

  test('unknown type and extra fields are rejected', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(addDoc(moments(db), {
      authorUid: 'alice', type: 'video', text: 'hi', createdAt: serverTimestamp(),
    }));
    await assertFails(addDoc(moments(db), {
      authorUid: 'alice', type: 'note', text: 'hi', createdAt: serverTimestamp(), likes: 5,
    }));
  });

  test('signed-in user can run the widget query', async () => {
    const db = env.authenticatedContext('bob').firestore();
    await assertSucceeds(getDocs(query(moments(db), orderBy('createdAt', 'desc'), limit(10))));
  });

  test('signed-out user can neither read nor write', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDocs(moments(db)));
    await assertFails(addDoc(moments(db), {
      authorUid: 'x', type: 'note', text: 'hi', createdAt: serverTimestamp(),
    }));
  });

  test('moments cannot be edited or deleted', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'couples/spike/moments/m1'), {
        authorUid: 'alice', type: 'note', text: 'hi', createdAt: new Date(),
      });
    });
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'couples/spike/moments/m1'), { text: 'sửa' }));
    await assertFails(deleteDoc(doc(db, 'couples/spike/moments/m1')));
  });

  test('other couples are closed', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertFails(getDocs(collection(db, 'couples/other/moments')));
    await assertFails(addDoc(collection(db, 'couples/other/moments'), {
      authorUid: 'alice', type: 'note', text: 'hi', createdAt: serverTimestamp(),
    }));
  });
});
