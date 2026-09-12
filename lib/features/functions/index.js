const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const customerPhone = data.customerPhone; // رقم العميل
    const title = data.title;
    const body = data.body;

    // جلب FCM token للعميل من Firestore
    // نفترض أنك حفظت fcmToken في مستند العميل أو مجموعة منفصلة
    const customerDoc = await admin
      .firestore()
      .collection('customers')
      .where('phone', '==', customerPhone)
      .limit(1)
      .get();

    if (customerDoc.empty) {
      console.log('❌ لا يوجد عميل بهذا الرقم');
      return null;
    }

    const token = customerDoc.docs[0].data().fcmToken;

    if (!token) {
      console.log('❌ لا يوجد FCM Token');
      return null;
    }

    const payload = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        orderId: data.orderId || '',
        status: data.status || '',
      },
    };

    try {
      await admin.messaging().sendToDevice(token, payload);
      console.log('✅ تم إرسال الإشعار');
    } catch (e) {
      console.error('❌ خطأ في الإرسال:', e);
    }
  });