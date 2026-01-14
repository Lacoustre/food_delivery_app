import { NextRequest, NextResponse } from 'next/server'
import { doc, getDoc } from 'firebase/firestore'
import { db } from '@/lib/firebase'

export async function POST(request: NextRequest) {
  try {
    const { type, email, phone, orderNumber, customerName, total, status, orderId } = await request.json()

    if (type === 'order_confirmation') {
      await Promise.all([
        sendEmail({
          to: email,
          subject: `Order Confirmation #${orderNumber}`,
          html: `
            <h2>Thank you for your order, ${customerName}!</h2>
            <p>Your order #${orderNumber} has been confirmed.</p>
            <p>Total: $${total.toFixed(2)}</p>
            <p>We'll notify you when your order is ready.</p>
          `
        }),
        sendSMS({
          to: phone,
          message: `Hi ${customerName}! Your order #${orderNumber} ($${total.toFixed(2)}) is confirmed. We'll update you on the status.`
        })
      ])
    } else if (type === 'status_update') {
      let orderData = null
      if (orderId) {
        const orderDoc = await getDoc(doc(db, 'orders', orderId))
        orderData = orderDoc.data()
      }

      const statusMessages = {
        preparing: 'Your order is being prepared',
        ready: 'Your order is ready for pickup',
        out_for_delivery: 'Your order is out for delivery',
        delivered: 'Your order has been delivered',
        completed: 'Order completed. Thank you!'
      }

      const message = `Order #${orderNumber}: ${statusMessages[status as keyof typeof statusMessages]}`
      
      await Promise.all([
        sendEmail({
          to: orderData?.customerInfo?.email || email,
          subject: `Order Update #${orderNumber}`,
          html: `
            <h2>Order Status Update</h2>
            <p>Hi ${orderData?.customerInfo?.name || customerName}!</p>
            <p>${message}</p>
            <p>Thank you for choosing Taste of African Cuisine!</p>
          `
        }),
        sendSMS({
          to: orderData?.customerInfo?.phone || phone,
          message: `Hi ${orderData?.customerInfo?.name || customerName}! ${message}`
        })
      ])
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Notification error:', error)
    return NextResponse.json({ error: 'Failed to send notification' }, { status: 500 })
  }
}

async function sendEmail({ to, subject, html }: { to: string, subject: string, html: string }) {
  // Placeholder for email service (SendGrid, AWS SES, etc.)
  console.log('Email sent to:', to, subject)
}

async function sendSMS({ to, message }: { to: string, message: string }) {
  // Placeholder for SMS service (Twilio, AWS SNS, etc.)
  console.log('SMS sent to:', to, message)
}