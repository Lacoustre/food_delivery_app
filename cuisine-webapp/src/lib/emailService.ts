import nodemailer from 'nodemailer'

if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
  console.error('EMAIL_USER and EMAIL_PASS must be set in environment variables')
}

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
})

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
      if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
        console.error('Gmail credentials not configured')
        return { success: false, error: 'Email service not configured' }
      }

      console.log('Sending welcome email to:', customerEmail)
      
      const result = await transporter.sendMail({
        from: `"Taste of African Cuisine" <tasteofafricancuisine01@gmail.com>`,
        to: customerEmail,
        subject: '🎉 Welcome to Taste of African Cuisine!',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #E65100; margin: 0;">🍽️ Welcome to Taste of African Cuisine!</h1>
            </div>
            
            <p style="font-size: 16px;">Hi ${customerName},</p>
            <p style="font-size: 16px;">Welcome! We're excited to have you try our authentic African dishes.</p>
            
            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <h3 style="color: #E65100; margin: 0 0 15px 0;">🇬🇭 What Makes Us Special</h3>
              <ul style="margin: 0; padding-left: 20px; line-height: 1.6;">
                <li><strong>Authentic Recipes:</strong> Traditional Ghanaian dishes passed down through generations</li>
                <li><strong>Fresh Ingredients:</strong> Premium quality ingredients sourced daily</li>
                <li><strong>Expert Chefs:</strong> Experienced cooks who bring authentic flavors to life</li>
                <li><strong>Fast Delivery:</strong> Hot, fresh meals delivered to your door</li>
              </ul>
            </div>
            
            <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0; text-align: center;"><strong>📍 Visit Us:</strong> 200 Hartford Turnpike, Vernon, CT</p>
              <p style="margin: 5px 0 0 0; text-align: center;"><strong>📞 Call:</strong> (929) 456-3215</p>
            </div>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #666; margin: 0;">Questions? Contact us at: <a href="mailto:tasteofafricancuisine01@gmail.com" style="color: #E65100;">tasteofafricancuisine01@gmail.com</a></p>
              <p style="color: #666; margin: 5px 0 0 0;">With love and spices,</p>
              <p style="color: #E65100; font-weight: bold; margin: 5px 0 0 0;">The Taste of African Cuisine Team</p>
            </div>
          </div>
        `
      })

      console.log('Welcome email sent successfully:', result.messageId)
      return { success: true, data: result }
    } catch (error) {
      console.error('Welcome email service error:', error)
      return { success: false, error }
    }
  },

  async sendOrderConfirmation(data: OrderEmailData) {
    try {
      const result = await transporter.sendMail({
        from: `"Taste of African Cuisine" <tasteofafricancuisine01@gmail.com>`,
        to: data.customerEmail,
        subject: `Order Confirmation #${data.orderNumber}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #E65100; margin: 0;">🍽️ Order Confirmed!</h1>
            </div>
            
            <p style="font-size: 16px;">Hi ${data.customerName},</p>
            <p style="font-size: 16px;">Thank you for your order! We're preparing your delicious African cuisine.</p>
            
            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #E65100;">
              <h3 style="margin: 0 0 15px 0; color: #E65100;">Order #${data.orderNumber}</h3>
              <p style="margin: 5px 0;"><strong>Type:</strong> ${data.orderType === 'delivery' ? 'Delivery' : 'Pickup'}</p>
              ${data.deliveryAddress ? `<p style="margin: 5px 0;"><strong>Address:</strong> ${data.deliveryAddress}</p>` : ''}
              
              <h4 style="margin: 15px 0 10px 0;">Items:</h4>
              <ul style="margin: 0; padding-left: 20px;">
                ${data.items.map(item => 
                  `<li style="margin: 5px 0;">${item.name} x${item.quantity} - $${(item.price * item.quantity).toFixed(2)}</li>`
                ).join('')}
              </ul>
              
              <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #ddd;">
                <p style="margin: 3px 0;">Subtotal: $${data.subtotal.toFixed(2)}</p>
                ${data.deliveryFee > 0 ? `<p style="margin: 3px 0;">Delivery Fee: $${data.deliveryFee.toFixed(2)}</p>` : ''}
                <p style="margin: 3px 0;">Tax: $${data.tax.toFixed(2)}</p>
                <p style="margin: 10px 0 0 0; font-size: 18px;"><strong>Total: $${data.total.toFixed(2)}</strong></p>
              </div>
            </div>
            
            ${data.estimatedTime ? `<p style="background: #e8f5e8; padding: 15px; border-radius: 8px; margin: 20px 0;"><strong>🕒 Estimated time:</strong> ${data.estimatedTime}</p>` : ''}
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #666; margin: 0;">Questions? Contact us at: <a href="mailto:tasteofafricancuisine01@gmail.com" style="color: #E65100;">tasteofafricancuisine01@gmail.com</a></p>
              <p style="color: #666; margin: 5px 0 0 0;">Best regards,</p>
              <p style="color: #E65100; font-weight: bold; margin: 5px 0 0 0;">Taste of African Cuisine Team</p>
            </div>
          </div>
        `
      })

      return { success: true, data: result }
    } catch (error) {
      console.error('Email service error:', error)
      return { success: false, error }
    }
  },

  async sendStatusUpdate(data: OrderEmailData) {
    try {
      const result = await transporter.sendMail({
        from: `"Taste of African Cuisine" <tasteofafricancuisine01@gmail.com>`,
        to: data.customerEmail,
        subject: `Order Update #${data.orderNumber} - ${data.status}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #E65100; margin: 0;">📱 Order Update</h1>
            </div>
            
            <p style="font-size: 16px;">Hi ${data.customerName},</p>
            
            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #E65100; text-align: center;">
              <h2 style="color: #E65100; margin: 0 0 10px 0;">${data.status}</h2>
              <p style="font-size: 18px; margin: 0;">Order #${data.orderNumber}</p>
              ${data.estimatedTime ? `<p style="background: #e8f5e8; padding: 10px; border-radius: 5px; margin: 15px 0 0 0;"><strong>🕒 ${data.estimatedTime}</strong></p>` : ''}
            </div>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
              <p style="color: #666; margin: 0;">Questions? Contact us at: <a href="mailto:tasteofafricancuisine01@gmail.com" style="color: #E65100;">tasteofafricancuisine01@gmail.com</a></p>
              <p style="color: #666; margin: 5px 0 0 0;">Best regards,</p>
              <p style="color: #E65100; font-weight: bold; margin: 5px 0 0 0;">Taste of African Cuisine Team</p>
            </div>
          </div>
        `
      })

      return { success: true, data: result }
    } catch (error) {
      console.error('Email service error:', error)
      return { success: false, error }
    }
  }
}