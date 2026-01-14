import { NextRequest, NextResponse } from 'next/server'
import { emailService } from '@/lib/emailService'

export async function POST(request: NextRequest) {
  try {
    const { type, orderData, email, name } = await request.json()

    switch (type) {
      case 'confirmation':
        if (!orderData) {
          return NextResponse.json({ error: 'Order data required for confirmation email' }, { status: 400 })
        }
        await emailService.sendOrderConfirmation(orderData)
        break
        
      case 'status_update':
        if (!orderData) {
          return NextResponse.json({ error: 'Order data required for status update email' }, { status: 400 })
        }
        await emailService.sendStatusUpdate(orderData)
        break
        
      case 'welcome':
        if (!email || !name) {
          return NextResponse.json({ error: 'Email and name required for welcome email' }, { status: 400 })
        }
        await emailService.sendWelcomeEmail(email, name)
        break
        
      default:
        return NextResponse.json({ error: 'Invalid email type' }, { status: 400 })
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Email API error:', error)
    return NextResponse.json({ 
      error: 'Failed to send email', 
      details: error instanceof Error ? error.message : 'Unknown error' 
    }, { status: 500 })
  }
}