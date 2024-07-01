import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const createUser = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.token || context.auth.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can create users.');
  }

  try {
    const userRecord = await admin.auth().createUser({
      email: data.email,
      password: data.password,
      displayName: data.displayName,
    });

    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: data.email,
      displayName: data.displayName,
      role: data.role,
    });

    return { uid: userRecord.uid };
  } catch (error) {
    console.error('Error creating new user:', error);
    throw new functions.https.HttpsError('internal', 'Unable to create user');
  }
});

