import React, { useState, useEffect, useRef } from 'react';
import { collection, query, orderBy, onSnapshot, addDoc, updateDoc, doc, where, getDocs, deleteDoc } from 'firebase/firestore';
import { db } from '../firebase';
import moment from 'moment';

interface Message {
  id: string;
  chatId: string;
  senderId: string;
  senderType: 'customer' | 'admin';
  message: string;
  timestamp: { seconds: number; nanoseconds: number };
  read: boolean;
}

interface Chat {
  id: string;
  customerId: string;
  customerName: string;
  customerEmail: string;
  lastMessage: string;
  lastMessageTime: { seconds: number; nanoseconds: number };
  unreadCount: number;
  status: 'active' | 'closed';
}

export default function Support() {
  const [chats, setChats] = useState<Chat[]>([]);
  const [selectedChat, setSelectedChat] = useState<Chat | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const chatsQuery = query(
      collection(db, 'support_chats'),
      orderBy('lastMessageTime', 'desc')
    );

    const unsubscribe = onSnapshot(chatsQuery, (snapshot) => {
      const chatData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Chat[];
      setChats(chatData);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  useEffect(() => {
    if (!selectedChat) return;

    const messagesQuery = query(
      collection(db, 'support_messages'),
      where('chatId', '==', selectedChat.id),
      orderBy('timestamp', 'asc')
    );

    const unsubscribe = onSnapshot(messagesQuery, (snapshot) => {
      const messageData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Message[];
      setMessages(messageData);
      
      // Mark messages as read
      snapshot.docs.forEach(async (docSnapshot) => {
        const message = docSnapshot.data() as Message;
        if (message.senderType === 'customer' && !message.read) {
          await updateDoc(doc(db, 'support_messages', docSnapshot.id), { read: true });
        }
      });
    });

    return () => unsubscribe();
  }, [selectedChat]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const sendMessage = async () => {
    if (!newMessage.trim() || !selectedChat) return;

    try {
      await addDoc(collection(db, 'support_messages'), {
        chatId: selectedChat.id,
        senderId: 'admin',
        senderType: 'admin',
        message: newMessage.trim(),
        timestamp: new Date(),
        read: false
      });

      await updateDoc(doc(db, 'support_chats', selectedChat.id), {
        lastMessage: newMessage.trim(),
        lastMessageTime: new Date(),
        unreadCount: 0
      });

      setNewMessage('');
    } catch (error) {
      console.error('Error sending message:', error);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const deleteChat = async (chatId: string) => {
    try {
      // Delete all messages
      const messagesQuery = query(
        collection(db, 'support_messages'),
        where('chatId', '==', chatId)
      );
      const messagesSnapshot = await getDocs(messagesQuery);
      
      const deletePromises = messagesSnapshot.docs.map(messageDoc => 
        deleteDoc(messageDoc.ref)
      );
      await Promise.all(deletePromises);
      
      // Delete chat
      await deleteDoc(doc(db, 'support_chats', chatId));
      
      if (selectedChat?.id === chatId) {
        setSelectedChat(null);
      }
    } catch (error) {
      console.error('Error deleting chat:', error);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-600"></div>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Support</h1>
          <p className="text-gray-600">Manage live chat conversations with customers.</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-[600px]">
        {/* Chat List */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
          <div className="p-4 border-b border-gray-200 bg-gray-50">
            <h2 className="font-semibold text-gray-900">Active Chats ({chats.length})</h2>
          </div>
          <div className="overflow-y-auto h-full">
            {chats.length === 0 ? (
              <div className="p-6 text-center text-gray-500">
                <svg className="w-12 h-12 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                <p>No active chats</p>
              </div>
            ) : (
              chats.map((chat) => (
                <div
                  key={chat.id}
                  className={`p-4 border-b border-gray-100 hover:bg-gray-50 transition-colors ${
                    selectedChat?.id === chat.id ? 'bg-orange-50 border-orange-200' : ''
                  }`}
                >
                  <div className="flex justify-between items-start mb-2">
                    <div 
                      onClick={() => setSelectedChat(chat)}
                      className="flex-1 cursor-pointer"
                    >
                      <h3 className="font-medium text-gray-900 truncate">{chat.customerName}</h3>
                    </div>
                    <div className="flex items-center space-x-2">
                      {chat.unreadCount > 0 && (
                        <span className="bg-orange-600 text-white text-xs rounded-full px-2 py-1 min-w-[20px] text-center">
                          {chat.unreadCount}
                        </span>
                      )}
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          if (window.confirm('Delete this chat permanently?')) {
                            deleteChat(chat.id);
                          }
                        }}
                        className="text-red-600 hover:text-red-800 p-1"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </button>
                    </div>
                  </div>
                  <div 
                    onClick={() => setSelectedChat(chat)}
                    className="cursor-pointer"
                  >
                    <p className="text-sm text-gray-600 truncate mb-1">{chat.lastMessage}</p>
                    <p className="text-xs text-gray-400">
                      {moment(chat.lastMessageTime.seconds * 1000).fromNow()}
                    </p>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Chat Messages */}
        <div className="lg:col-span-2 bg-white rounded-lg shadow-sm border border-gray-200 flex flex-col">
          {selectedChat ? (
            <>
              {/* Chat Header */}
              <div className="p-4 border-b border-gray-200 bg-gray-50">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="font-semibold text-gray-900">{selectedChat.customerName}</h3>
                    <p className="text-sm text-gray-600">{selectedChat.customerEmail}</p>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      {selectedChat.status === 'active' ? 'Online' : 'Closed'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto p-4 space-y-4">
                {messages.map((message) => (
                  <div
                    key={message.id}
                    className={`flex ${message.senderType === 'admin' ? 'justify-end' : 'justify-start'}`}
                  >
                    <div
                      className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                        message.senderType === 'admin'
                          ? 'bg-orange-600 text-white'
                          : 'bg-gray-200 text-gray-900'
                      }`}
                    >
                      <p className="text-sm">{message.message}</p>
                      <p className={`text-xs mt-1 ${
                        message.senderType === 'admin' ? 'text-orange-100' : 'text-gray-500'
                      }`}>
                        {moment(message.timestamp.seconds * 1000).format('h:mm A')}
                      </p>
                    </div>
                  </div>
                ))}
                <div ref={messagesEndRef} />
              </div>

              {/* Message Input */}
              <div className="p-4 border-t border-gray-200">
                <div className="flex space-x-2">
                  <input
                    type="text"
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    onKeyPress={handleKeyPress}
                    placeholder="Type your message..."
                    className="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
                  />
                  <button
                    onClick={sendMessage}
                    disabled={!newMessage.trim()}
                    className="bg-orange-600 text-white px-4 py-2 rounded-lg hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-orange-500 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                    </svg>
                  </button>
                </div>
              </div>
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center text-gray-500">
              <div className="text-center">
                <svg className="w-16 h-16 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                <p className="text-lg font-medium">Select a chat to start messaging</p>
                <p className="text-sm">Choose a conversation from the list to view messages</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}