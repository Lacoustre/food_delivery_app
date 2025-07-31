const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");
const stripe = require("stripe"); 

admin.initializeApp();
const messaging = admin.messaging();

// Secrets
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const SENDGRID_API_KEY = defineSecret("SENDGRID_API_KEY");
const FROM_EMAIL = defineSecret("FROM_EMAIL");

// --- FCM Token Management ---
exports.updateFCMToken = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  const { token } = request.data;
  if (!token) {
    throw new HttpsError('invalid-argument', 'FCM token is required');
  }

  try {
    await admin.firestore()
      .collection('users')
      .doc(request.auth.uid)
      .update({
        fcmToken: token,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
    return { success: true };
  } catch (error) {
    logger.error("❌ Error updating FCM token", { error: error.message });
    throw new HttpsError('internal', 'Failed to update FCM token');
  }
});

// --- Create Payment Intent Function ---
// The most common causes of "INTERNAL" errors in Cloud Functions:

// 1. STRIPE SECRET KEY ISSUE

exports.createPaymentIntent = onCall(
  {
    secrets: [STRIPE_SECRET_KEY],
    enforceAppCheck: false,
    cors: true,
  },
  async (request) => {
    try {
      logger.log("🚀 Function started");

      const stripeSecretKey = STRIPE_SECRET_KEY.value();
      logger.log("🔑 Stripe key check", {
        hasKey: !!stripeSecretKey,
        keyLength: stripeSecretKey?.length || 0,
        keyPrefix: stripeSecretKey?.substring(0, 8) || 'none',
      });

      if (!stripeSecretKey) {
        logger.error("❌ No Stripe secret key found");
        throw new HttpsError("internal", "Stripe configuration missing");
      }

      if (!stripeSecretKey.startsWith('sk_')) {
        logger.error("❌ Invalid Stripe secret key format", {
          keyPrefix: stripeSecretKey.substring(0, 10),
        });
        throw new HttpsError("internal", "Invalid Stripe key format");
      }

      if (!request.auth) {
        logger.error("❌ No authentication");
        throw new HttpsError("unauthenticated", "User must be authenticated");
      }

      const { amount, orderId, customerName, currency = "usd" } = request.data;

      logger.log("📦 Request data", {
        amount,
        amountType: typeof amount,
        orderId,
        customerName,
        currency,
        hasAllFields: !!(amount && orderId && customerName),
      });

      if (typeof amount !== "number" || amount <= 0 || isNaN(amount)) {
        logger.error("❌ Invalid amount", { amount, type: typeof amount });
        throw new HttpsError("invalid-argument", `Invalid amount: ${amount}`);
      }

      if (!orderId || typeof orderId !== "string") {
        logger.error("❌ Invalid orderId", { orderId, type: typeof orderId });
        throw new HttpsError("invalid-argument", "Invalid orderId");
      }

      if (!customerName || typeof customerName !== "string") {
        logger.error("❌ Invalid customerName", { customerName, type: typeof customerName });
        throw new HttpsError("invalid-argument", "Invalid customerName");
      }

      logger.log("🔧 Initializing Stripe client");
      const stripeLib = require("stripe");
      const stripeClient = stripeLib(stripeSecretKey);

      if (!stripeClient) {
        logger.error("❌ Failed to initialize Stripe client");
        throw new HttpsError("internal", "Stripe initialization failed");
      }

      const amountInCents = Math.round(amount * 100);
      logger.log("💰 Amount processing", {
        originalAmount: amount,
        amountInCents,
        isValidAmount: amountInCents >= 50,
      });

      if (amountInCents < 50) {
        throw new HttpsError("invalid-argument", `Minimum amount is $0.50, got $${amount}`);
      }

      logger.log("💳 Creating Stripe PaymentIntent");

      const paymentIntentParams = {
        amount: amountInCents,
        currency: currency.toLowerCase(),
        payment_method_types: ["card"],
        metadata: {
          orderId: orderId.trim(),
          customerName: customerName.trim(),
          userId: request.auth.uid,
          timestamp: new Date().toISOString(),
        },
        description: `Payment for order ${orderId}`,
      };

      if (request.auth.token?.email) {
        paymentIntentParams.receipt_email = request.auth.token.email;
      }

      logger.log("📋 PaymentIntent params", paymentIntentParams);

      const paymentIntent = await stripeClient.paymentIntents.create(paymentIntentParams);

      logger.log("✅ PaymentIntent created successfully", {
        id: paymentIntent.id,
        amount: paymentIntent.amount,
        status: paymentIntent.status,
        hasClientSecret: !!paymentIntent.client_secret,
      });

      const response = {
        client_secret: paymentIntent.client_secret,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        status: paymentIntent.status,
        orderId: orderId,
      };

      logger.log("📤 Returning response", {
        hasClientSecret: !!response.client_secret,
        clientSecretLength: response.client_secret?.length,
      });

      return response;

    } catch (error) {
      console.error("💥 Unexpected function error:", error);

      logger.error("💥 Function error", {
        errorMessage: error?.message || 'No message',
        errorType: error?.constructor?.name || 'UnknownType',
        errorCode: error?.code?.toString?.() ?? 'none',
        errorStack: error?.stack?.substring?.(0, 800),
        isHttpsError: error instanceof HttpsError,
        isStripeError: error?.type?.startsWith?.('Stripe') ?? false,
        stripeErrorType: error?.type?.toString?.() ?? 'none',
        stripeErrorCode: error?.code?.toString?.() ?? 'none',
        requestData: {
          amount: request.data?.amount,
          orderId: request.data?.orderId,
          customerName: request.data?.customerName,
        },
        authUid: request.auth?.uid ?? 'anonymous',
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      if (error?.type?.startsWith?.('Stripe')) {
        const stripeErrorMessage = `Stripe error: ${error.message || 'Unknown stripe error'}`;
        logger.error("🔴 Stripe API error", {
          type: error?.type,
          code: error?.code,
          message: error?.message,
        });
        throw new HttpsError("internal", stripeErrorMessage);
      }

      const genericMessage = `Internal error: ${error.message || 'Unknown error'}`;
      logger.error("🔴 Unexpected error", {
        errorMessage: genericMessage,
      });

      throw new HttpsError("internal", genericMessage);
    }
  }
);

// --- Create Order Function with FCM ---
exports.createOrder = onCall(
  async (request) => {
    const { data } = request;
    if (!request.auth) {
      logger.error("❌ Unauthenticated request");
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    if (!data.orderNumber || !data.userId || !data.items || !data.pricing || !data.delivery || !data.payment || !data.status) {
      logger.error("❌ Missing required fields", { data });
      throw new HttpsError("invalid-argument", "Missing required order fields");
    }

    if (data.userId !== request.auth.uid) {
      logger.error("❌ User ID mismatch", { dataUserId: data.userId, authUid: request.auth.uid });
      throw new HttpsError("permission-denied", "User ID does not match authenticated user");
    }

    const db = admin.firestore();
    const batch = db.batch();

    try {
      // Write to global orders collection
      const orderRef = db.collection("orders").doc(data.orderNumber);
      batch.set(orderRef, {
        orderNumber: data.orderNumber,
        userId: data.userId,
        items: data.items,
        pricing: data.pricing,
        delivery: data.delivery,
        payment: data.payment,
        status: "received", // Always set to 'received' for new orders
        statusHistory: data.statusHistory,
        eta: data.eta || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Write to user's orders subcollection
      const userOrderRef = db.collection("users").doc(data.userId).collection("orders").doc(data.orderNumber);
      batch.set(userOrderRef, {
        orderId: data.orderNumber,
        orderNumber: data.orderNumber,
        userId: data.userId,
        total: data.pricing.total,
        status: "received", // Always set to 'received' for new orders
        items: data.items,
        pricing: data.pricing,
        delivery: data.delivery,
        payment: data.payment,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create order confirmation notification
      const notificationRef = db.collection("users").doc(data.userId).collection("notifications").doc();
      batch.set(notificationRef, {
        type: "order_confirmed",
        title: "Order Confirmed",
        body: `Thank you, ${data.payment.customerName || "Customer"}! Your order #${data.orderNumber} has been confirmed.`,
        orderId: data.orderNumber,
        items: data.items.map(item => `${item.name} x${item.quantity}`).join(", ") || "N/A",
        totalAmount: data.pricing.total.toFixed(2),
        customerName: data.payment.customerName || "Customer",
        estimatedDelivery: data.delivery.option === "Delivery" ? "30-45 minutes" : "N/A",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();
      
      // Send FCM notification
      const userDoc = await db.collection('users').doc(data.userId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        const message = {
          notification: {
            title: "✅ Order Confirmed",
            body: `Your order #${data.orderNumber} has been received!`
          },
          data: {
            type: "order_confirmed",
            orderId: data.orderNumber,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            screen: "orderDetails"
          },
          token: userDoc.data().fcmToken
        };
        
        await messaging.send(message);
        logger.info("📲 Order confirmation FCM sent", { orderId: data.orderNumber });
      }

      logger.info("✅ Order and notification created", { orderId: data.orderNumber, userId: data.userId });
      return { success: true, orderId: data.orderNumber };
    } catch (error) {
      logger.error("❌ Error saving order", { error: error.message });
      throw new HttpsError("internal", `Failed to save order: ${error.message}`);
    }
  }
);

// --- Enhanced Order Status Update Trigger with FCM ---
exports.onOrderStatusUpdated = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const newData = event.data.after.data();
    const previousData = event.data.before.data();
    const orderId = event.params.orderId;
    const userId = newData.userId;

    if (!userId) {
      logger.warn("⚠️ No userId found in order", { orderId });
      return;
    }

    const db = admin.firestore();
    const notificationRef = db.collection("users").doc(userId).collection("notifications");

    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    // Handle order status changes
    if (newData.status !== previousData.status) {
      let notificationData = null;
      let fcmMessage = null;
      
      // Update order with status timestamp
      const statusTimestamp = admin.firestore.FieldValue.serverTimestamp();
      const statusUpdateData = {
        [`${newData.status}Time`]: statusTimestamp,
        updatedAt: statusTimestamp
      };
      
      // Update the order document with timestamp
      await db.collection('orders').doc(orderId).update(statusUpdateData);

      switch (newData.status) {
        case "received":
          notificationData = {
            type: "order_received",
            title: "Order Received",
            body: `Your order #${orderId} has been received and will be processed shortly!`,
            orderId: orderId,
            customerName: newData.customerName || "Customer",
            receivedTime: statusTimestamp,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          fcmMessage = {
            notification: {
              title: "📥 Order Received",
              body: `Your order #${orderId} has been received!`
            },
            data: {
              type: "order_received",
              orderId: orderId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              screen: "orderDetails"
            }
          };
          break;
          
        case "preparing":
          notificationData = {
            type: "order_preparing",
            title: "Order Being Prepared",
            body: `Your order #${orderId} is being prepared!`,
            orderId: orderId,
            estimatedTime: newData.estimatedTime || "20-30 minutes",
            customerName: newData.customerName || "Customer",
            preparingTime: statusTimestamp,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          fcmMessage = {
            notification: {
              title: "👨‍🍳 Order Being Prepared",
              body: `Chefs are working on your order #${orderId}`
            },
            data: {
              type: "order_preparing",
              orderId: orderId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              screen: "orderDetails"
            }
          };
          break;
          
        case "ready":
        case "ready for pickup":
          notificationData = {
            type: "order_ready",
            title: "Order Ready",
            body: `Your order #${orderId} is ready for pickup!`,
            orderId: orderId,
            pickupLocation: newData.delivery?.address || "Restaurant",
            readyTime: statusTimestamp,
            customerName: newData.customerName || "Customer",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          fcmMessage = {
            notification: {
              title: "🍽️ Order Ready!",
              body: `Your order #${orderId} is ready for pickup`
            },
            data: {
              type: "order_ready",
              orderId: orderId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              screen: "orderDetails"
            }
          };
          break;
          
        case "picked up":
          notificationData = {
            type: "order_picked_up",
            title: "Order Picked Up",
            body: `Your order #${orderId} has been picked up! Enjoy your meal!`,
            orderId: orderId,
            pickupTime: statusTimestamp,
            customerName: newData.customerName || "Customer",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          fcmMessage = {
            notification: {
              title: "✅ Order Picked Up!",
              body: `Your order #${orderId} has been picked up! Enjoy!`
            },
            data: {
              type: "order_picked_up",
              orderId: orderId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              screen: "orderDetails"
            }
          };
          break;
          
        case "delivered":
          notificationData = {
            type: "order_delivered",
            title: "Order Delivered",
            body: `Your order #${orderId} has been delivered! Enjoy!`,
            orderId: orderId,
            deliveryAddress: newData.delivery?.address || "N/A",
            deliveryTime: statusTimestamp,
            customerName: newData.customerName || "Customer",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          fcmMessage = {
            notification: {
              title: "🎉 Order Delivered!",
              body: `Your order #${orderId} has arrived! Enjoy your meal!`
            },
            data: {
              type: "order_delivered",
              orderId: orderId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              screen: "orderDetails"
            }
          };
          break;
          
        default:
          logger.info("ℹ️ No notification needed for status", { status: newData.status });
          return;
      }

      if (notificationData) {
        // Save to Firestore
        await notificationRef.add(notificationData);
        logger.info("✅ Notification created for status", { status: newData.status, orderId, userId });
        
        // Send FCM if token exists
        if (fcmToken) {
          try {
            await messaging.send({ ...fcmMessage, token: fcmToken });
            logger.info("📲 FCM notification sent", { orderId, userId });
          } catch (error) {
            logger.error("❌ FCM send error", { error: error.message });
          }
        }
      }
    }

    // Handle driver assignment
    if (newData.driverId && newData.driverId !== previousData.driverId) {
      await notifyDriverAssigned(orderId, newData.driverId);
    }
  }
);

// --- Driver Assignment Notification ---
async function notifyDriverAssigned(orderId, driverId) {
  try {
    const db = admin.firestore();
    
    // Get driver's FCM token
    const driverDoc = await db.collection('drivers').doc(driverId).get();
    if (!driverDoc.exists) return;
    
    const driverData = driverDoc.data();
    const fcmToken = driverData.fcmToken;
    
    if (!fcmToken) {
      logger.warn('No FCM token for driver', { driverId });
      return;
    }

    // Get order details
    const orderDoc = await db.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) return;
    
    const orderData = orderDoc.data();
    
    // Create driver notification in Firestore
    await db.collection('drivers')
      .doc(driverId)
      .collection('notifications')
      .add({
        type: 'new_assignment',
        title: 'New Delivery Assignment',
        body: `Order #${orderId} - ${orderData.items.length} items`,
        orderId: orderId,
        customerName: orderData.payment.customerName || 'Customer',
        deliveryAddress: orderData.delivery?.address || 'N/A',
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

    // Send FCM to driver
    const message = {
      notification: {
        title: '🚗 New Delivery Assignment',
        body: `Order #${orderId} - Tap to view details`
      },
      data: {
        type: 'new_assignment',
        orderId: orderId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: 'driverOrderDetails'
      },
      token: fcmToken
    };
    
    await messaging.send(message);
    logger.info('🚗 Driver assignment notification sent', { orderId, driverId });
    
  } catch (error) {
    logger.error('❌ Driver notification error', { 
      error: error.message,
      orderId,
      driverId
    });
  }
}

// --- Promotional Notifications ---
exports.sendPromotionalNotification = onCall(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    // Only allow admin users
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(request.auth.uid)
      .get();
      
    if (!userDoc.exists || userDoc.data().role !== 'admin') {
      throw new HttpsError('permission-denied', 'Admin access required');
    }

    const { title, body, imageUrl, offerId } = request.data;
    if (!title || !body) {
      throw new HttpsError('invalid-argument', 'Title and body are required');
    }

    try {
      // Get all user FCM tokens who have opted in for promotions
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('fcmToken', '!=', null)
        .where('notificationPreferences.promotions', '==', true)
        .get();

      const tokens = usersSnapshot.docs
        .map(doc => doc.data().fcmToken)
        .filter(token => token);

      if (tokens.length === 0) {
        return { success: true, message: 'No eligible users with FCM tokens' };
      }

      // Batch send notifications (max 500 per batch)
      const batchSize = 500;
      const batches = Math.ceil(tokens.length / batchSize);
      let successCount = 0;
      let failureCount = 0;

      for (let i = 0; i < batches; i++) {
        const batchTokens = tokens.slice(i * batchSize, (i + 1) * batchSize);
        
        const message = {
          notification: {
            title: title,
            body: body,
            ...(imageUrl && { imageUrl: imageUrl })
          },
          data: {
            type: 'promotion',
            offerId: offerId || '',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'offers'
          },
          tokens: batchTokens
        };

        try {
          const response = await messaging.sendMulticast(message);
          successCount += response.successCount;
          failureCount += response.failureCount;
          
          if (response.failureCount > 0) {
            response.responses.forEach((resp, idx) => {
              if (!resp.success) {
                logger.warn('Failed to send to token', {
                  token: batchTokens[idx],
                  error: resp.error?.message
                });
              }
            });
          }
        } catch (error) {
          logger.error('Error sending batch', { batch: i, error: error.message });
          failureCount += batchTokens.length;
        }
      }

      logger.info('📢 Promo notification results', {
        successCount,
        failureCount
      });

      return { 
        success: true,
        sentCount: successCount,
        failedCount: failureCount
      };
    } catch (error) {
      logger.error('❌ Promo notification error', { error: error.message });
      throw new HttpsError('internal', 'Failed to send notifications');
    }
  }
);

// --- Send Email Function ---
exports.sendOrderEmail = onCall(
  {
    secrets: [SENDGRID_API_KEY],
  },
  async (request) => {
    const { to, subject, html } = request.data;
    const fromEmail = FROM_EMAIL.value() || "orders@tasteofafricancuisine.com";

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!to || !emailRegex.test(to) || !subject || !html) {
      logger.error("❌ Invalid email fields", { to, subject });
      throw new HttpsError("invalid-argument", "Missing or invalid email fields.");
    }

    try {
      sgMail.setApiKey(SENDGRID_API_KEY.value());
      await sgMail.send({
        to,
        from: fromEmail,
        subject,
        html,
      });
      logger.info("✅ Email sent", { to, subject });
      return { success: true };
    } catch (error) {
      logger.error("❌ SendGrid Error:", { error: error.message });
      throw new HttpsError("internal", "Failed to send email: " + error.message);
    }
  }
);

// --- Notification Email Trigger Function ---
exports.onNotificationCreated = onDocumentCreated(
  {
    document: "users/{userId}/notifications/{notificationId}",
    secrets: [SENDGRID_API_KEY, FROM_EMAIL],
  },
  async (event) => {
    const { userId, notificationId } = event.params;
    const notificationData = event.data.data();
    const fromEmail = FROM_EMAIL.value() || "orders@tasteofafricancuisine.com";

    logger.info("🔔 Notification created", {
      userId,
      notificationId,
      type: notificationData.type,
    });

    try {
      // Get user's email and preferences
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      if (!userDoc.exists) {
        logger.warn("⚠️ User not found", { userId });
        return;
      }

      const userData = userDoc.data();
      const userEmail = userData.email;

      if (!userEmail) {
        logger.warn("⚠️ User email not found", { userId });
        return;
      }

      if (userData.emailNotifications === false) {
        logger.info("📧 Email notifications disabled for user", { userId });
        return;
      }

      // Notification type mapping
      const notificationTypes = {
        order_received: {
          subject: '📥 Order Received - Taste of African Cuisine',
          template: createOrderReceivedEmail
        },
        order_confirmed: {
          subject: '✅ Order Confirmed - Taste of African Cuisine',
          template: createOrderConfirmationEmail
        },
        order_preparing: {
          subject: '👨‍🍳 Your Order is Being Prepared - Taste of African Cuisine',
          template: createOrderPreparingEmail
        },
        order_ready: {
          subject: '🍽️ Your Order is Ready - Taste of African Cuisine',
          template: createOrderReadyEmail
        },
        order_picked_up: {
          subject: '✅ Order Picked Up - Taste of African Cuisine',
          template: createOrderPickedUpEmail
        },
        order_delivered: {
          subject: '🎉 Order Delivered - Taste of African Cuisine',
          template: createDeliveryNotificationEmail
        },
        default: {
          subject: notificationData.title || 'Notification - Taste of African Cuisine',
          template: createGenericNotificationEmail
        }
      };

      const { subject, template } = notificationTypes[notificationData.type || 'default'];
      const htmlContent = template(notificationData);

      // Send email with retry mechanism
      const MAX_RETRIES = 3;
      let retries = 0;
      while (retries < MAX_RETRIES) {
        try {
          sgMail.setApiKey(SENDGRID_API_KEY.value());
          await sgMail.send({
            to: userEmail,
            from: fromEmail,
            subject: subject,
            html: htmlContent,
          });
          logger.info("✅ Email sent successfully", { userEmail, type: notificationData.type });

          await event.data.ref.update({
            emailSent: true,
            emailSentAt: admin.firestore.FieldValue.serverTimestamp()
          });
          return;
        } catch (error) {
          retries++;
          if (retries === MAX_RETRIES) {
            logger.error("❌ Max retries reached for email", { error: error.message });
            await event.data.ref.update({
              emailSent: false,
              emailError: error.message,
              emailAttemptedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            return;
          }
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 1000));
        }
      }
    } catch (error) {
      logger.error("❌ Error in onNotificationCreated", { error: error.message });
      await event.data.ref.update({
        emailSent: false,
        emailError: error.message,
        emailAttemptedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  }
);

// --- Update Notification Preferences ---
exports.updateNotificationPreferences = onCall(async (request) => {
  const { auth } = request;
  const { enabled, preferences } = request.data;

  if (!auth) {
    logger.error("❌ Unauthenticated request");
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    await admin.firestore()
      .collection('users')
      .doc(auth.uid)
      .set(
        {
          notificationPreferences: {
            promotions: preferences?.promotions ?? true,
            orderUpdates: preferences?.orderUpdates ?? true,
            deliveryUpdates: preferences?.deliveryUpdates ?? true,
          },
          notificationsEnabled: enabled,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        },
        { merge: true }
      );

    logger.info("✅ Notification preferences updated", { userId: auth.uid, enabled });
    return { success: true, message: 'Notification preferences updated' };
  } catch (error) {
    logger.error("❌ Error updating notification preferences", { error: error.message });
    throw new HttpsError('internal', 'Failed to update preferences: ' + error.message);
  }
});

// --- Email Template Functions ---
function createOrderReceivedEmail(notificationData) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Received</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #007bff 0%, #0056b3 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="margin: 0; font-size: 28px;">📥 Order Received!</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px;">Taste of African Cuisine</p>
      </div>
      <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
        <h2 style="color: #007bff; margin-top: 0;">Hi ${notificationData.customerName || 'Valued Customer'},</h2>
        <p style="font-size: 16px; margin-bottom: 25px;">
          Thank you for your order! We have received your order and our team will begin processing it shortly.
          You'll receive updates as your order progresses.
        </p>
        <div style="background-color: white; padding: 20px; border-radius: 8px; border-left: 4px solid #007bff; margin: 25px 0;">
          <h3 style="color: #007bff; margin-top: 0;">📋 Order Details</h3>
          <div style="margin-bottom: 15px;">
            <strong>Order ID:</strong> <span style="color: #666;">${notificationData.orderId || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Status:</strong> <span style="color: #007bff; font-weight: bold;">Received</span>
          </div>
        </div>
        <div style="background-color: #d1ecf1; padding: 15px; border-radius: 8px; border-left: 4px solid #17a2b8; margin: 25px 0;">
          <p style="margin: 0; color: #0c5460;">
            <strong>⏳ What's Next?</strong><br>
            Our team will review and confirm your order. You'll receive another notification once we start preparing your delicious meal!
          </p>
        </div>
      </div>
      <div style="background-color: #333; color: white; padding: 20px; text-align: center; border-radius: 0 0 10px 10px; margin-top: 0;">
        <p style="margin: 0; font-size: 14px;">
          Thank you for choosing Taste of African Cuisine!<br>
          This is an automated message. Please do not reply to this email.
        </p>
      </div>
    </body>
    </html>
  `;
}

function createOrderConfirmationEmail(notificationData) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Confirmed</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #ff6b35 0%, #f7931e 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="margin: 0; font-size: 28px;">🎉 Order Confirmed!</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px;">Taste of African Cuisine</p>
      </div>
      <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
        <h2 style="color: #ff6b35; margin-top: 0;">Hi ${notificationData.customerName || 'Valued Customer'},</h2>
        <p style="font-size: 16px; margin-bottom: 25px;">
          Thank you for your order! We're excited to prepare your delicious African cuisine.
          Your order has been confirmed and our chefs are getting started.
        </p>
        <div style="background-color: white; padding: 20px; border-radius: 8px; border-left: 4px solid #ff6b35; margin: 25px 0;">
          <h3 style="color: #ff6b35; margin-top: 0;">📋 Order Details</h3>
          <div style="margin-bottom: 15px;">
            <strong>Order ID:</strong> <span style="color: #666;">${notificationData.orderId || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Total Amount:</strong> <span style="color: #ff6b35; font-size: 18px; font-weight: bold;">$${notificationData.totalAmount || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Items:</strong><br>
            <span style="color: #666;">${notificationData.items || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Estimated Ready Time:</strong> <span style="color: #666;">${notificationData.estimatedDelivery || 'N/A'}</span>
          </div>
        </div>
        <div style="text-align: center; margin-top: 30px;">
          <a href="${notificationData.trackingUrl || '#'}" 
             style="background: linear-gradient(135deg, #ff6b35 0%, #f7931e 100%); color: white; padding: 15px 30px; 
                    text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
            Track Your Order
          </a>
        </div>
      </div>
      <div style="background-color: #333; color: white; padding: 20px; text-align: center; border-radius: 0 0 10px 10px; margin-top: 0;">
        <p style="margin: 0; font-size: 14px;">
          Thank you for choosing Taste of African Cuisine!<br>
          This is an automated message. Please do not reply to this email.
        </p>
      </div>
    </body>
    </html>
  `;
}

function createOrderPreparingEmail(notificationData) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Being Prepared</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #fd7e14 0%, #ffc107 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="margin: 0; font-size: 28px;">👨‍🍳 Order Being Prepared</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px;">Taste of African Cuisine</p>
      </div>
      <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
        <h2 style="color: #fd7e14; margin-top: 0;">Hi ${notificationData.customerName || 'Valued Customer'},</h2>
        <p style="font-size: 16px; margin-bottom: 25px;">
          Good news! Our chefs have started preparing your order.
          We're cooking up something delicious just for you!
        </p>
        <div style="background-color: white; padding: 20px; border-radius: 8px; border-left: 4px solid #fd7e14; margin: 25px 0;">
          <div style="margin-bottom: 15px;">
            <strong>Order ID:</strong> <span style="color: #666;">${notificationData.orderId || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Estimated Ready Time:</strong> <span style="color: #fd7e14; font-weight: bold;">${notificationData.estimatedTime || 'N/A'}</span>
          </div>
        </div>
        <div style="text-align: center; margin-top: 30px;">
          <a href="${notificationData.trackingUrl || '#'}" 
             style="background: linear-gradient(135deg, #fd7e14 0%, #ffc107 100%); color: white; padding: 15px 30px; 
                    text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
            Track Progress
          </a>
        </div>
      </div>
      <div style="background-color: #333; color: white; padding: 20px; text-align: center; border-radius: 0 0 10px 10px; margin-top: 0;">
        <p style="margin: 0; font-size: 14px;">
          Thank you for choosing Taste of African Cuisine!<br>
          This is an automated message. Please do not reply to this email.
        </p>
      </div>
    </body>
    </html>
  `;
}

function createOrderReadyEmail(notificationData) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Ready</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #198754 0%, #20c997 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="margin: 0; font-size: 28px;">🍽️ Order Ready!</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px;">Taste of African Cuisine</p>
      </div>
      <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
        <h2 style="color: #198754; margin-top: 0;">Hi ${notificationData.customerName || 'Valued Customer'},</h2>
        <p style="font-size: 16px; margin-bottom: 25px;">
          Your order is ready! Come pick it up while it's hot and fresh.
          Our delicious African cuisine is waiting for you!
        </p>
        <div style="background-color: white; padding: 20px; border-radius: 8px; border-left: 4px solid #198754; margin: 25px 0;">
          <div style="margin-bottom: 15px;">
            <strong>Order ID:</strong> <span style="color: #666;">${notificationData.orderId || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Pickup Location:</strong> <span style="color: #666;">${notificationData.pickupLocation || 'Restaurant'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Ready Since:</strong> <span style="color: #666;">${notificationData.readyTime || 'Just now'}</span>
          </div>
        </div>
        <div style="background-color: #fff3cd; padding: 15px; border-radius: 8px; border-left: 4px solid #ffc107; margin: 25px 0;">
          <p style="margin: 0; color: #856404;">
            <strong>⏰ Please pick up within 15 minutes</strong><br>
            to ensure your food stays fresh and delicious!
          </p>
        </div>
      </div>
      <div style="background-color: #333; color: white; padding: 20px; text-align: center; border-radius: 0 0 10px 10px; margin-top: 0;">
        <p style="margin: 0; font-size: 14px;">
          Thank you for choosing Taste of African Cuisine!<br>
          This is an automated message. Please do not reply to this email.
        </p>
      </div>
    </body>
    </html>
  `;
}

function createOrderPickedUpEmail(notificationData) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Picked Up</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #20c997 0%, #198754 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="margin: 0; font-size: 28px;">✅ Order Picked Up!</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px;">Taste of African Cuisine</p>
      </div>
      <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
        <h2 style="color: #20c997; margin-top: 0;">Hi ${notificationData.customerName || 'Valued Customer'},</h2>
        <p style="font-size: 16px; margin-bottom: 25px;">
          Thank you for picking up your order! We hope you enjoy your delicious African cuisine.
          Your meal is fresh and ready to be enjoyed!
        </p>
        <div style="background-color: white; padding: 20px; border-radius: 8px; border-left: 4px solid #20c997; margin: 25px 0;">
          <h3 style="color: #20c997; margin-top: 0;">📋 Pickup Details</h3>
          <div style="margin-bottom: 15px;">
            <strong>Order ID:</strong> <span style="color: #666;">${notificationData.orderId || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Picked up at:</strong> <span style="color: #666;">${notificationData.pickupTime || 'Just now'}</span>
          </div>
        </div>
        <div style="background-color: #d1ecf1; padding: 15px; border-radius: 8px; border-left: 4px solid #17a2b8; margin: 25px 0;">
          <p style="margin: 0; color: #0c5460;">
            <strong>🍽️ Enjoy your meal!</strong><br>
            We'd love to hear about your dining experience. Your feedback helps us serve you better.
          </p>
        </div>
        <div style="text-align: center; margin-top: 30px;">
          <a href="${notificationData.reviewUrl || '#'}" 
             style="background: linear-gradient(135deg, #20c997 0%, #198754 100%); color: white; padding: 15px 30px; 
                    text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
            Leave a Review
          </a>
        </div>
      </div>
      <div style="background-color: #333; color: white; padding: 20px; text-align: center; border-radius: 0 0 10px 10px; margin-top: 0;">
        <p style="margin: 0; font-size: 14px;">
          Thank you for choosing Taste of African Cuisine!<br>
          This is an automated message. Please do not reply to this email.
        </p>
      </div>
    </body>
    </html>
  `;
}

function createDeliveryNotificationEmail(notificationData) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Order Delivered</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #6f42c1 0%, #e83e8c 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="margin: 0; font-size: 28px;">🎉 Order Delivered!</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px;">Taste of African Cuisine</p>
      </div>
      <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
        <h2 style="color: #6f42c1; margin-top: 0;">Hi ${notificationData.customerName || 'Valued Customer'},</h2>
        <p style="font-size: 16px; margin-bottom: 25px;">
          Great news! Your delicious African cuisine has been successfully delivered.
          We hope you enjoy every bite!
        </p>
        <div style="background-color: white; padding: 20px; border-radius: 8px; border-left: 4px solid #6f42c1; margin: 25px 0;">
          <h3 style="color: #6f42c1; margin-top: 0;">📋 Delivery Details</h3>
          <div style="margin-bottom: 15px;">
            <strong>Order ID:</strong> <span style="color: #666;">${notificationData.orderId || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Delivered to:</strong> <span style="color: #666;">${notificationData.deliveryAddress || 'N/A'}</span>
          </div>
          <div style="margin-bottom: 15px;">
            <strong>Delivery Time:</strong> <span style="color: #666;">${notificationData.deliveryTime || 'N/A'}</span>
          </div>
        </div>
        <div style="background-color: #d1ecf1; padding: 15px; border-radius: 8px; border-left: 4px solid #17a2b8; margin: 25px 0;">
          <p style="margin: 0; color: #0c5460;">
            <strong>📝 How was your experience?</strong><br>
            We'd love to hear about your meal! Your feedback helps us serve you better.
          </p>
        </div>
        <div style="text-align: center; margin-top: 30px;">
          <a href="${notificationData.reviewUrl || '#'}" 
             style="background: linear-gradient(135deg, #6f42c1 0%, #e83e8c 100%); color: white; padding: 15px 30px; 
                    text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
            Leave a Review
          </a>
        </div>
      </div>
      <div style="background-color: #333; color: white; padding: 20px; text-align: center; border-radius: 0 0 10px 10px; margin-top: 0;">
        <p style="margin: 0; font-size: 14px;">
          Thank you for choosing Taste of African Cuisine!<br>
          This is an automated message. Please do not reply to this email.
        </p>
      </div>
    </body>
    </html>
  `;
}

function createGenericNotificationEmail(notificationData) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Notification</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #ff6b35 0%, #f7931e 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="margin: 0; font-size: 28px;">${notificationData.title || 'Notification'}</h1>
        <p style="margin: 10px 0 0 0; font-size: 16px;">Taste of African Cuisine</p>
      </div>
      <div style="background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
        <p style="font-size: 16px; margin-bottom: 25px;">
          ${notificationData.body || 'You have a new notification from Taste of African Cuisine.'}
        </p>
        ${notificationData.actionUrl ? `
          <div style="text-align: center; margin-top: 30px;">
            <a href="${notificationData.actionUrl}" 
               style="background: linear-gradient(135deg, #ff6b35 0%, #f7931e 100%); color: white; padding: 15px 30px; 
                      text-decoration: none; border-radius: 25px; display: inline-block; font-weight: bold; font-size: 16px;">
              View Details
            </a>
          </div>
        ` : ''}
      </div>
      <div style="background-color: #333; color: white; padding: 20px; text-align: center; border-radius: 0 0 10px 10px; margin-top: 0;">
        <p style="margin: 0; font-size: 14px;">
          Thank you for choosing Taste of African Cuisine!<br>
          This is an automated message. Please do not reply to this email.
        </p>
      </div>
    </body>
    </html>
  `;
}