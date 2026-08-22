import React, { useState, useEffect, useRef, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import moment from 'moment';

// Support chat lives in Supabase support_chats/support_messages — the same
// tables the mobile app's live chat uses.
interface Message {
  id: string;
  chat_id: string;
  sender_id: string;
  sender_type: 'customer' | 'admin';
  message: string;
  created_at: string;
  read: boolean;
}

interface Chat {
  id: string;
  customer_id: string;
  customerName: string;
  customerEmail: string;
  last_message: string | null;
  last_message_time: string | null;
  unread_count: number;
  status: 'active' | 'closed';
}

export default function Support() {
  const [chats, setChats] = useState<Chat[]>([]);
  const [selectedChat, setSelectedChat] = useState<Chat | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const fetchChats = useCallback(async () => {
    const { data } = await supabase
      .from('support_chats')
      .select('*, profiles!customer_id(name, email)')
      .order('last_message_time', { ascending: false, nullsFirst: false });
    setChats(
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (data ?? []).map((row: any) => {
        const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
        return {
          id: row.id,
          customer_id: row.customer_id,
          customerName: profile?.name || profile?.email || 'Customer',
          customerEmail: profile?.email || '',
          last_message: row.last_message,
          last_message_time: row.last_message_time,
          unread_count: row.unread_count ?? 0,
          status: row.status,
        };
      }),
    );
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchChats();
    const channel = supabase
      .channel('support-chats-admin')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'support_chats' }, fetchChats)
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetchChats]);

  useEffect(() => {
    if (!selectedChat) return;

    const fetchMessages = async () => {
      const { data } = await supabase
        .from('support_messages')
        .select('*')
        .eq('chat_id', selectedChat.id)
        .order('created_at', { ascending: true });
      setMessages((data ?? []) as Message[]);

      // Mark the customer's messages as read + clear the unread badge
      await supabase
        .from('support_messages')
        .update({ read: true })
        .eq('chat_id', selectedChat.id)
        .eq('sender_type', 'customer')
        .eq('read', false);
      await supabase.from('support_chats').update({ unread_count: 0 }).eq('id', selectedChat.id);
    };

    fetchMessages();
    const channel = supabase
      .channel(`support-messages-${selectedChat.id}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'support_messages', filter: `chat_id=eq.${selectedChat.id}` },
        fetchMessages,
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [selectedChat]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const sendMessage = async () => {
    if (!newMessage.trim() || !selectedChat) return;

    try {
      const { data: userData } = await supabase.auth.getUser();
      if (!userData?.user) throw new Error('Not signed in to Supabase');

      const { error } = await supabase.from('support_messages').insert({
        chat_id: selectedChat.id,
        sender_id: userData.user.id,
        sender_type: 'admin',
        message: newMessage.trim(),
        read: false,
      });
      if (error) throw error;

      await supabase
        .from('support_chats')
        .update({
          last_message: newMessage.trim(),
          last_message_time: new Date().toISOString(),
          unread_count: 0,
        })
        .eq('id', selectedChat.id);

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
      // Messages cascade via the chat FK
      const { error } = await supabase.from('support_chats').delete().eq('id', chatId);
      if (error) throw error;

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
                      {chat.unread_count > 0 && (
                        <span className="bg-orange-600 text-white text-xs rounded-full px-2 py-1 min-w-[20px] text-center">
                          {chat.unread_count}
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
                    <p className="text-sm text-gray-600 truncate mb-1">{chat.last_message}</p>
                    <p className="text-xs text-gray-400">
                      {chat.last_message_time ? moment(chat.last_message_time).fromNow() : ''}
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
                    className={`flex ${message.sender_type === 'admin' ? 'justify-end' : 'justify-start'}`}
                  >
                    <div
                      className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                        message.sender_type === 'admin'
                          ? 'bg-orange-600 text-white'
                          : 'bg-gray-200 text-gray-900'
                      }`}
                    >
                      <p className="text-sm">{message.message}</p>
                      <p className={`text-xs mt-1 ${
                        message.sender_type === 'admin' ? 'text-orange-100' : 'text-gray-500'
                      }`}>
                        {moment(message.created_at).format('h:mm A')}
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
