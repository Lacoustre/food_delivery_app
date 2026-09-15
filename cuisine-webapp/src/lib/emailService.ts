/**
 * Transactional email via Resend.
 *
 * Previously Gmail SMTP through nodemailer, which caps around 500 recipients a
 * day, needs an App Password that breaks whenever 2FA settings change, and has
 * no SPF/DKIM alignment for our domain — so confirmations often landed in spam.
 *
 * FROM_EMAIL must sit on a domain verified in Resend. The Deno edge function
 * at supabase/functions/send-order-email sends the same way; keep them in step.
 *
 * Markup here is deliberately old-fashioned — tables, inline styles, web-safe
 * fonts. Gmail strips <head> entirely, Outlook renders through Word, and
 * neither supports flexbox or grid. Anything cleverer breaks in the clients
 * most customers actually use.
 */

const FROM = process.env.FROM_EMAIL ||
  'Taste of African Cuisine <orders@tasteofafricancuisine.com>'

// The one place these live. They were previously scattered through the
// templates, which is how a personal Gmail address ended up being the contact
// on every order confirmation.
const RESTAURANT = {
  name: 'Taste of African Cuisine',
  address: '200 Hartford Turnpike, Vernon, CT 06066',
  phone: '(860) 805-5121',
  phoneHref: '+18608055121',
  email: 'orders@tasteofafricancuisine.com'
}

// Matches globals.css so an email looks like the site the order came from.
const C = {
  gold: '#C9982E',
  kente: '#14543D',
  clay: '#A8452C',
  ink: '#1A1512',
  sand: '#FAF7F2',
  sandLine: '#E5E0D8',
  muted: '#6B6257'
}

const FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"

// Served from Supabase Storage rather than the site, so it resolves the same
// whatever the site is deployed at — and keeps working if the domain moves.
const LOGO = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/email-logo.png'

/** Names and addresses are customer-supplied; a stray < would break the layout. */
function esc(v: unknown): string {
  return String(v ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

const money = (n: number) => `$${(Number(n) || 0).toFixed(2)}`

/** The database stores snake_case; customers should not have to read it. */
function statusLabel(
  status: string,
  orderType?: 'delivery' | 'pickup'
): { title: string; blurb: string } {
  // The admin panel folds "delivered" and "picked up" into "completed", so by
  // the time this runs the specific word is gone. The order type still says
  // which happened, and "Delivered — enjoy your meal" is worth more to a
  // customer than a generic "order complete".
  const s = String(status).toLowerCase()
  if (s === 'completed') {
    if (orderType === 'delivery') return { title: 'Delivered', blurb: 'Enjoy your meal.' }
    if (orderType === 'pickup') return { title: 'Picked up', blurb: 'Thanks for collecting — enjoy your meal.' }
  }

  switch (s) {
    case 'pending':
      return { title: 'Order received', blurb: 'We have your order and will confirm it shortly.' }
    case 'confirmed':
      return { title: 'Order confirmed', blurb: 'The kitchen has your order.' }
    case 'preparing':
      return { title: 'Being prepared', blurb: 'Your food is being cooked fresh.' }
    // The admin panel writes "on the way" and "picked up"; the mobile app and
    // the original schema use out_for_delivery. Both vocabularies are live, so
    // both are handled — a status that falls through gets emailed to the
    // customer verbatim, in lowercase, which is how "out_for_delivery" once
    // ended up in a subject line.
    case 'out_for_delivery':
    case 'on the way':
      return { title: 'Out for delivery', blurb: 'Your driver is on the way.' }
    case 'delivered':
      return { title: 'Delivered', blurb: 'Enjoy your meal.' }
    case 'picked up':
      return { title: 'Picked up', blurb: 'Thanks for collecting — enjoy your meal.' }
    case 'completed':
      return { title: 'Order complete', blurb: 'Thanks for ordering with us.' }
    case 'ready':
    case 'ready for pickup':
      return { title: 'Ready for pickup', blurb: 'Your order is ready to collect.' }
    case 'cancelled':
      return { title: 'Order canceled', blurb: 'This order has been canceled. If you paid by card, the refund has been issued and usually reaches your bank within 5-10 days. Anything unclear, reply to this email.' }
    default:
      return { title: String(status), blurb: '' }
  }
}

function layout(preheader: string, inner: string): string {
  return `
<div style="background:${C.sand};margin:0;padding:24px 12px;font-family:${FONT};">
  <span style="display:none;font-size:1px;color:${C.sand};max-height:0;overflow:hidden;">${esc(preheader)}</span>
  <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid ${C.sandLine};">
    <tr>
      <td style="background:#ffffff;padding:26px 28px 20px;text-align:center;border-bottom:3px solid ${C.gold};">
        <img src="${LOGO}" width="118" height="118" alt="Taste of African Cuisine"
             style="display:block;margin:0 auto 12px auto;border:0;outline:none;text-decoration:none;width:118px;height:118px;">
        <div style="color:${C.kente};font-size:17px;font-weight:700;letter-spacing:1.4px;text-transform:uppercase;">
          Taste of African Cuisine
        </div>
        <div style="color:${C.muted};font-size:12px;letter-spacing:0.5px;margin-top:5px;">
          Authentic African cooking &middot; Vernon, CT
        </div>
      </td>
    </tr>
    <tr><td style="padding:28px;color:${C.ink};font-size:15px;line-height:1.55;">${inner}</td></tr>
    <tr>
      <td style="background:${C.sand};border-top:1px solid ${C.sandLine};padding:20px 28px;color:${C.muted};font-size:12.5px;line-height:1.7;">
        <strong style="color:${C.ink};">${RESTAURANT.name}</strong><br>
        ${RESTAURANT.address}<br>
        <a href="tel:${RESTAURANT.phoneHref}" style="color:${C.clay};text-decoration:none;">${RESTAURANT.phone}</a>
        &nbsp;&middot;&nbsp;
        <a href="mailto:${RESTAURANT.email}" style="color:${C.clay};text-decoration:none;">${RESTAURANT.email}</a>
      </td>
    </tr>
  </table>
</div>`
}

function heading(text: string): string {
  return `<h1 style="margin:0 0 14px 0;color:${C.kente};font-size:22px;font-weight:700;">${esc(text)}</h1>`
}

/** Where to collect, on a pickup order. Previously missing entirely: a pickup
 *  confirmation said "Type: Pickup" and never gave an address. */
function pickupBlock(): string {
  return `
  <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:18px 0;">
    <tr><td style="background:${C.sand};border-left:3px solid ${C.gold};padding:14px 16px;">
      <div style="font-weight:700;color:${C.ink};margin-bottom:4px;">Collect from</div>
      <div style="color:${C.ink};">${RESTAURANT.address}</div>
      <div style="margin-top:6px;"><a href="tel:${RESTAURANT.phoneHref}" style="color:${C.clay};text-decoration:none;">${RESTAURANT.phone}</a></div>
    </td></tr>
  </table>`
}

async function sendEmail({ to, subject, html }: {
  to: string
  subject: string
  html: string
}) {
  const apiKey = process.env.RESEND_API_KEY
  if (!apiKey) throw new Error('RESEND_API_KEY is not configured')

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`
    },
    body: JSON.stringify({ from: FROM, to: [to], subject, html })
  })

  if (!res.ok) {
    // Resend explains itself in the body — an unverified sender domain and a
    // bad key are indistinguishable from the status code alone.
    throw new Error(`Resend request failed: ${res.status} ${await res.text()}`)
  }
  return res.json()
}

export interface OrderEmailData {
  customerEmail: string
  customerName: string
  orderNumber: string
  orderType: 'delivery' | 'pickup'
  items: Array<{
    id: string
    name: string
    quantity: number
    price: number
  }>
  subtotal: number
  deliveryFee: number
  tax: number
  total: number
  deliveryAddress?: string
  status: string
  estimatedTime?: string
}

export const emailService = {
  async sendWelcomeEmail(customerEmail: string, customerName: string) {
    try {
      const result = await sendEmail({
        to: customerEmail,
        subject: `Welcome to ${RESTAURANT.name}`,
        html: layout(
          'Your account is ready — browse the menu and order for delivery or pickup.',
          `
          ${heading('Welcome, ' + customerName)}
          <p style="margin:0 0 14px 0;">
            Thanks for creating an account. You can now order for delivery across the
            Vernon area, or for pickup from the restaurant.
          </p>
          <p style="margin:0 0 20px 0;color:${C.muted};">
            Everything is cooked to order, so give us a little time — it is worth the wait.
          </p>
          ${pickupBlock()}
        `)
      })
      return { success: true, data: result }
    } catch (error) {
      console.error('Welcome email service error:', error)
      return { success: false, error }
    }
  },

  /**
   * Tells the restaurant an order has come in.
   *
   * Nothing did this before — every email the system sent went to the
   * customer, so an order could sit on the site with nobody at the restaurant
   * aware of it unless somebody happened to be watching the admin panel. The
   * Clover ticket is the primary signal; this is the one that survives a POS
   * that is offline or a printer out of paper.
   *
   * Deliberately plain. It is read on a phone in a kitchen, usually in a
   * hurry, so what matters is at the top and nothing needs scrolling past.
   */
  async sendNewOrderAlert(
    data: OrderEmailData & { customerPhone?: string; scheduledFor?: string | null; paymentMethod?: string },
    to: string
  ) {
    try {
      const rows = data.items.map(item => `
        <tr>
          <td style="padding:7px 0;border-bottom:1px solid ${C.sandLine};font-size:15px;">
            <strong style="color:${C.clay};">${item.quantity} &times;</strong> ${esc(item.name)}
          </td>
          <td style="padding:7px 0;border-bottom:1px solid ${C.sandLine};text-align:right;font-size:15px;white-space:nowrap;">
            $${(item.price * item.quantity).toFixed(2)}
          </td>
        </tr>`).join('')

      const when = data.scheduledFor
        ? new Intl.DateTimeFormat('en-US', {
            timeZone: 'America/New_York',
            weekday: 'short',
            hour: 'numeric',
            minute: '2-digit'
          }).format(new Date(data.scheduledFor))
        : null

      const cash = data.paymentMethod === 'cash'

      const result = await sendEmail({
        to,
        subject:
          `${when ? `[${when}] ` : ''}New ${data.orderType} order #${data.orderNumber}` +
          ` — $${data.total.toFixed(2)}${cash ? ' CASH' : ''}`,
        html: layout(
          `${data.orderType} · $${data.total.toFixed(2)}${when ? ` · for ${when}` : ''}`,
          `
          ${heading(`Order #${esc(data.orderNumber)}`)}

          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:0 0 18px 0;">
            <tr>
              <td style="padding:12px 14px;background:${C.sand};border-left:4px solid ${C.gold};font-size:15px;line-height:1.6;">
                <strong style="color:${C.kente};text-transform:uppercase;letter-spacing:0.5px;">
                  ${data.orderType}
                </strong>${when ? ` &middot; <strong>for ${when}</strong>` : ' &middot; as soon as possible'}
                <br>
                ${esc(data.customerName)}${data.customerPhone
                  ? ` &middot; <a href="tel:${esc(data.customerPhone)}" style="color:${C.clay};">${esc(data.customerPhone)}</a>`
                  : ''}
                ${data.deliveryAddress ? `<br>${esc(data.deliveryAddress)}` : ''}
              </td>
            </tr>
          </table>

          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
            ${rows}
            <tr>
              <td style="padding:12px 0 0 0;font-size:17px;font-weight:700;">Total</td>
              <td style="padding:12px 0 0 0;text-align:right;font-size:17px;font-weight:700;">
                $${data.total.toFixed(2)}
              </td>
            </tr>
          </table>

          <p style="margin:16px 0 0 0;font-size:15px;${cash ? `color:${C.clay};font-weight:700;` : `color:${C.muted};`}">
            ${cash ? `Collect $${data.total.toFixed(2)} in cash on collection.` : 'Already paid by card.'}
          </p>
        `)
      })
      return { success: true, data: result }
    } catch (error) {
      console.error('New order alert failed:', error)
      return { success: false, error }
    }
  },

  async sendOrderConfirmation(data: OrderEmailData) {
    try {
      const rows = data.items.map(item => `
        <tr>
          <td style="padding:9px 0;border-bottom:1px solid ${C.sandLine};color:${C.ink};">
            ${esc(item.name)}
            <span style="color:${C.muted};">&times;${Number(item.quantity) || 0}</span>
          </td>
          <td style="padding:9px 0;border-bottom:1px solid ${C.sandLine};text-align:right;white-space:nowrap;color:${C.ink};">
            ${money(item.price * item.quantity)}
          </td>
        </tr>`).join('')

      const totalRow = (label: string, value: string, strong = false) => `
        <tr>
          <td style="padding:${strong ? '11px 0 0 0' : '4px 0'};color:${strong ? C.ink : C.muted};font-size:${strong ? '17px' : '14px'};font-weight:${strong ? '700' : '400'};">${label}</td>
          <td style="padding:${strong ? '11px 0 0 0' : '4px 0'};text-align:right;color:${strong ? C.gold : C.muted};font-size:${strong ? '17px' : '14px'};font-weight:${strong ? '700' : '400'};">${value}</td>
        </tr>`

      const result = await sendEmail({
        to: data.customerEmail,
        subject: `Order #${data.orderNumber} confirmed — ${RESTAURANT.name}`,
        html: layout(
          `We have your order. Total ${money(data.total)}.`,
          `
          ${heading('Order confirmed')}
          <p style="margin:0 0 6px 0;">Hi ${esc(data.customerName)},</p>
          <p style="margin:0 0 18px 0;color:${C.muted};">
            Thank you — we have your order and the kitchen is on it.
          </p>

          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-bottom:6px;">
            <tr>
              <td style="color:${C.muted};font-size:13px;">Order</td>
              <td style="text-align:right;color:${C.ink};font-weight:700;">#${esc(data.orderNumber)}</td>
            </tr>
            <tr>
              <td style="color:${C.muted};font-size:13px;">Type</td>
              <td style="text-align:right;color:${C.ink};">${data.orderType === 'delivery' ? 'Delivery' : 'Pickup'}</td>
            </tr>
            ${data.estimatedTime ? `<tr>
              <td style="color:${C.muted};font-size:13px;">Estimated</td>
              <td style="text-align:right;color:${C.ink};">${esc(data.estimatedTime)}</td>
            </tr>` : ''}
          </table>

          ${data.orderType === 'delivery' && data.deliveryAddress
            ? `<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:18px 0;">
                 <tr><td style="background:${C.sand};border-left:3px solid ${C.gold};padding:14px 16px;">
                   <div style="font-weight:700;color:${C.ink};margin-bottom:4px;">Delivering to</div>
                   <div style="color:${C.ink};">${esc(data.deliveryAddress)}</div>
                 </td></tr>
               </table>`
            : pickupBlock()}

          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-top:8px;">
            ${rows}
          </table>

          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-top:14px;">
            ${totalRow('Subtotal', money(data.subtotal))}
            ${data.deliveryFee > 0 ? totalRow('Delivery', money(data.deliveryFee)) : ''}
            ${totalRow('Tax', money(data.tax))}
            ${totalRow('Total', money(data.total), true)}
          </table>
        `)
      })
      return { success: true, data: result }
    } catch (error) {
      console.error('Order confirmation email error:', error)
      return { success: false, error }
    }
  },

  async sendStatusUpdate(data: OrderEmailData) {
    try {
      const { title, blurb } = statusLabel(data.status, data.orderType)
      const result = await sendEmail({
        to: data.customerEmail,
        subject: `Order #${data.orderNumber} — ${title}`,
        html: layout(
          `${title}. ${blurb}`,
          `
          ${heading(title)}
          <p style="margin:0 0 6px 0;">Hi ${esc(data.customerName)},</p>
          ${blurb ? `<p style="margin:0 0 18px 0;color:${C.muted};">${esc(blurb)}</p>` : ''}

          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:16px 0;">
            <tr><td style="background:${C.sand};border-left:3px solid ${C.gold};padding:14px 16px;">
              <div style="color:${C.muted};font-size:13px;">Order</div>
              <div style="color:${C.ink};font-weight:700;font-size:17px;">#${esc(data.orderNumber)}</div>
              ${data.estimatedTime ? `<div style="margin-top:6px;color:${C.ink};">${esc(data.estimatedTime)}</div>` : ''}
            </td></tr>
          </table>

          ${data.orderType === 'pickup' && String(data.status).toLowerCase() === 'ready' ? pickupBlock() : ''}
        `)
      })
      return { success: true, data: result }
    } catch (error) {
      console.error('Status update email error:', error)
      return { success: false, error }
    }
  }
}
