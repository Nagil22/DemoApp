"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getUserByEmail = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
exports.getUserByEmail = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    const { email } = data;
    const firestore = admin.firestore();
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated to perform this action");
    }
    const parentId = (_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid;
    try {
        // Check if child already exists in the 'users' collection
        const usersCollection = firestore.collection("users");
        const childQuery = await usersCollection.where("email", "==", email)
            .limit(1).get();
        let childId;
        if (!childQuery.empty) {
            const childDoc = childQuery.docs[0];
            childId = childDoc.id;
        }
        else {
            // If the child doesn't exist, create a new child user
            const parentDoc = await usersCollection.doc(parentId).get();
            const newChildRef = await usersCollection.add({
                email: email,
                role: "student",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "active",
                schoolCode: ((_b = parentDoc.data()) === null || _b === void 0 ? void 0 : _b.schoolCode) || "",
            });
            childId = newChildRef.id;
        }
        // Create notification for the school admin in the notifications subcollection
        const parentDoc = await usersCollection.doc(parentId).get();
        const parentName = (_c = parentDoc.data()) === null || _c === void 0 ? void 0 : _c.name;
        const schoolCode = (_d = parentDoc.data()) === null || _d === void 0 ? void 0 : _d.schoolCode;
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
        return { childId };
    }
    catch (error) {
        // Check if the error is an instance of Error to safely access its message
        if (error instanceof Error) {
            throw new functions.https.HttpsError("unknown", error.message);
        }
        else {
            throw new functions.https.HttpsError("unknown", "An unknown error occurred");
        }
    }
});
//# sourceMappingURL=index.js.map