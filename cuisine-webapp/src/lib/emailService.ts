import { Resend } from 'resend'

const resend = new Resend(process.env.RESEND_API_KEY)

interface OrderEmailData {
  customerEmail: string
  customerName: string
  orderNumber: number
  orderType: 'delivery' | 'pickup'
  items: Array<{
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
  async sendOrderConfirmation(orderData: OrderEmailData) {
    try {
      const { data, error } = await resend.emails.send({
        from: 'Taste of African Cuisine <orders@tasteofafricancuisine.com>',
        to: [orderData.customerEmail],
        subject: `Order Confirmed #${orderData.orderNumber} - Taste of African Cuisine`,
        text: `Hi ${orderData.customerName},\n\nYour order #${orderData.orderNumber} has been confirmed!\n\nOrder Details:\n${orderData.items.map(item => `${item.quantity}x ${item.name} - $${(item.price * item.quantity).toFixed(2)}`).join('\n')}\n\nSubtotal: $${orderData.subtotal.toFixed(2)}\n${orderData.deliveryFee > 0 ? `Delivery Fee: $${orderData.deliveryFee.toFixed(2)}\n` : ''}Tax: $${orderData.tax.toFixed(2)}\nTotal: $${orderData.total.toFixed(2)}\n\n${orderData.deliveryAddress ? `Delivery Address: ${orderData.deliveryAddress}\n\n` : ''}Thank you for choosing Taste of African Cuisine!\n\nQuestions? Call us at (929) 456-3215`
      })

      if (error) {
        console.error('Order confirmation email error:', error)
        throw error
      }

      console.log('Order confirmation email sent:', data)
      return data
    } catch (error) {
      console.error('Failed to send order confirmation:', error)
      throw error
    }
  },

  async sendStatusUpdate(orderData: OrderEmailData) {
    try {
      const { data, error } = await resend.emails.send({
        from: 'Taste of African Cuisine <orders@tasteofafricancuisine.com>',
        to: [orderData.customerEmail],
        subject: `Order Update #${orderData.orderNumber} - ${orderData.status}`,
        text: `Hi ${orderData.customerName},\n\nYour order #${orderData.orderNumber} status has been updated to: ${orderData.status}\n\n${orderData.estimatedTime ? `Estimated time: ${orderData.estimatedTime}\n\n` : ''}${orderData.orderType === 'delivery' && orderData.deliveryAddress ? `Delivery Address: ${orderData.deliveryAddress}\n\n` : ''}Thank you for choosing Taste of African Cuisine!\n\nQuestions? Call us at (929) 456-3215`
      })

      if (error) {
        console.error('Status update email error:', error)
        throw error
      }

      console.log('Status update email sent:', data)
      return data
    } catch (error) {
      console.error('Failed to send status update:', error)
      throw error
    }
  },

  async sendWelcomeEmail(email: string, name: string) {
    try {
      const { data, error } = await resend.emails.send({
        from: 'Taste of African Cuisine <welcome@tasteofafricancuisine.com>',
        to: [email],
        subject: 'Welcome to Taste of African Cuisine!',
        text: `Hi ${name}!\n\nWelcome to Taste of African Cuisine!\n\nWe're excited to serve you authentic Ghanaian cuisine. Explore our menu and enjoy traditional flavors made with love.\n\nStart ordering at: ${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}\n\nThank you for joining us!`
      })

      if (error) {
        console.error('Welcome email error:', error)
        throw error
      }

      return data
    } catch (error) {
      console.error('Failed to send welcome email:', error)
      throw error
    }
  }
}