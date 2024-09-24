import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
admin.initializeApp();

export const getUserByEmail = functions.https.onCall(async (data, context) => {
  const {email} = data;
  const firestore = admin.firestore();

  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to perform this action"
    );
  }

  const parentId = context.auth?.uid;

  try {
    // Check if child already exists in the 'users' collection
    const usersCollection = firestore.collection("users");
    const childQuery = await usersCollection.where("email", "==", email)
      .limit(1).get();

    let childId: string;
    if (!childQuery.empty) {
      const childDoc = childQuery.docs[0];
      childId = childDoc.id;
    } else {
      // If the child doesn't exist, create a new child user
      const parentDoc = await usersCollection.doc(parentId).get();
      const newChildRef = await usersCollection.add({
        email: email,
        role: "student",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
        schoolCode: parentDoc.data()?.schoolCode || "",
      });
      childId = newChildRef.id;
    }

    // Create notification for the school admin in the notifications subcollection
    const parentDoc = await usersCollection.doc(parentId).get();
    const parentName = parentDoc.data()?.name;
    const schoolCode = parentDoc.data()?.schoolCode;

    await firestore.collection("schools").doc(schoolCode)
      .collection("notifications").add({
        type: "parentRequest",
        parentId: parentId,
        parentName: parentName,
        childId: childId,
        status: "pending",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });

    // Add childId to parent's childrenIds array
    await usersCollection.doc(parentId).update({
      childrenIds: admin.firestore.FieldValue.arrayUnion(childId),
    });

    return {childId};
  } catch (error) {
    // Check if the error is an instance of Error to safely access its message
    if (error instanceof Error) {
      throw new functions.https.HttpsError("unknown", error.message);
    } else {
      throw new functions.https.HttpsError("unknown", "An unknown error occurred");
    }
  }
});

