import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { verifyAuth } from '@/lib/verifyAuth'

export async function POST(request: NextRequest) {
  try {
    const decodedToken = await verifyAuth(request)
    if (!decodedToken) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { type, email, phone, orderNumber, customerName, total, status, orderId } = await request.json()

    if (type === 'order_confirmation') {
      // Only allow notifying the caller's own verified email — prevents an
      // authenticated-but-malicious caller from using this endpoint to spam
      // or phish arbitrary recipients under the restaurant's name.
      if (email !== decodedToken.email) {
        return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
      }

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
      // Look up the order in Supabase (scoped to the caller's own token,
      // so RLS enforces they can only read their own orders) and pull the
      // customer contact info off the joined profile.
      let orderData: { customerInfo?: { name?: string; email?: string; phone?: string } } | null = null
      if (orderId) {
        const supabase = createClient(
          process.env.NEXT_PUBLIC_SUPABASE_URL!,
          process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
          { global: { headers: { Authorization: request.headers.get('authorization')! } } }
        )
        const { data: order } = await supabase
          .from('orders')
          .select('id, profiles!user_id(name, email, phone)')
          .eq('id', orderId)
          .maybeSingle()
        const profile = Array.isArray(order?.profiles) ? order?.profiles[0] : order?.profiles
        if (profile) {
          orderData = { customerInfo: { name: profile.name, email: profile.email, phone: profile.phone } }
        }
      }

      // Only allow notifying the order's own customer — verified against
      // the order record itself (or the `email` field as a fallback when
      // no orderId was supplied), never trusted blindly from the client.
      const targetEmail = orderData?.customerInfo?.email || email
      if (targetEmail !== decodedToken.email) {
        return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
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