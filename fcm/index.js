const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.firestore.document('notifications/{notificationId}')
    .onCreate(async (snapshot, context) => {
      const notification = snapshot.data();
      const tokens = []; // Array of device tokens to send the notification to

      const payload = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
      };

      const response = await admin.messaging().sendToDevice(tokens, payload);
      console.log('Notification sent:', response);
    });

