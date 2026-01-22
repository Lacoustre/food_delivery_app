import { NextRequest, NextResponse } from 'next/server'
import { emailService, type OrderEmailData } from '@/lib/emailService'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { type, orderData, welcomeData }: { 
      type: 'confirmation' | 'status_update' | 'welcome', 
      orderData?: OrderEmailData,
      welcomeData?: { customerEmail: string, customerName: string }
    } = body

    if (!type) {
      return NextResponse.json({ error: 'Missing email type' }, { status: 400 })
    }

    let result
    if (type === 'confirmation' || type === 'status_update') {
      if (!orderData) {
        return NextResponse.json({ error: 'Missing order data' }, { status: 400 })
      }
      
      if (type === 'confirmation') {
        result = await emailService.sendOrderConfirmation(orderData)
      } else {
        result = await emailService.sendStatusUpdate(orderData)
      }
    } else if (type === 'welcome') {
      if (!welcomeData) {
        return NextResponse.json({ error: 'Missing welcome data' }, { status: 400 })
      }
      
      result = await emailService.sendWelcomeEmail(welcomeData.customerEmail, welcomeData.customerName)
    } else {
      return NextResponse.json({ error: 'Invalid email type' }, { status: 400 })
    }

    if (result.success) {
      return NextResponse.json({ success: true, data: result.data })
    } else {
      return NextResponse.json({ error: result.error }, { status: 500 })
    }
  } catch (error) {
    console.error('Email API error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}