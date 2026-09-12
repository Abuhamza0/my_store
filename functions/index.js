process.env.FUNCTIONS_TIMEOUT_SECONDS = "60";

const functions = require("firebase-functions");
const admin = require("firebase-admin");

// تهيئة Firebase Admin مع إعدادات محسنة
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || "mystore-d2838",
  });
}

exports.sendordertostore = functions.https.onCall(async (data) => {
  try {
    let storeId = data.storeId;
    const order = data.order;

    if (!order) {
      throw new functions.https.HttpsError("invalid-argument", "الطلب مفقود");
    }

    // ✅ إذا كان storeId فارغًا أو default_store، نحاول تصحيحه
    if (!storeId || storeId === "default_store") {
      console.log("⚠️ storeId غير صالح، جاري محاولة التصحيح...");

      // 1) من بيانات العميل
      if (order.customerId) {
        const customerDoc = await admin.firestore()
          .collection("customers")
          .doc(order.customerId)
          .get();

        if (customerDoc.exists) {
          const customerData = customerDoc.data();
          storeId = customerData.store_id || customerData.storeId || "";
        }
      }

      // 2) إذا لم يوجد، نشتق من البريد الإلكتروني للعميل إن وجد
      if ((!storeId || storeId === "default_store") && order.customerEmail) {
        storeId = order.customerEmail
          .trim()
          .toLowerCase()
          .replace(/@/g, "_")
          .replace(/\./g, "_");
      }

      // 3) إذا لم نجد، نستخدم قيمة افتراضية
      if (!storeId || storeId === "default_store") {
        storeId = "store_Id";
      }

      console.log("🔧 تم تصحيح storeId إلى:", storeId);
    }

    // ✅ حفظ الطلب مع store_id الصحيح
    const orderRef = await admin.firestore().collection("orders").add({
      ...order,
      store_id: storeId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      status: "pending",
    });

    // ✅ إرسال إشعار (اختياري)
    const tokensSnapshot = await admin.firestore()
      .collection("store_owner_tokens")
      .doc(storeId)
      .collection("tokens")
      .get();

    const tokens = tokensSnapshot.docs.map((doc) => doc.data().token).filter(Boolean);

    if (tokens.length > 0) {
      const payload = {
        notification: {
          title: "طلب جديد 🛒",
          body: `طلب من ${order.customerName} بقيمة ${order.totalAmount}`,
        },
        data: {
          orderId: orderRef.id,
          storeId: storeId,
        },
      };

      await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        ...payload,
      });
    }

    return { success: true, orderId: orderRef.id, storeId: storeId };
  } catch (error) {
    console.error("❌ فشل رفع الطلب:", error);
    throw new functions.https.HttpsError("internal", "فشل رفع الطلب");
  }
});