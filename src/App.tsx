/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from 'react';
import { 
  MessageSquare, 
  Users, 
  Rss, 
  Search, 
  MoreVertical, 
  Mic, 
  Plus,
  ArrowLeft,
  CheckCheck
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

// --- Types ---
interface Chat {
  id: string;
  name: string;
  lastMessage: string;
  time: string;
  unreadCount: number;
  isOnline: boolean;
}

// --- Mock Data ---
const MOCK_CHATS: Chat[] = [
  { id: '1', name: 'Ahmet Yılmaz', lastMessage: 'Sesli mesaj: 0:45', time: '14:20', unreadCount: 2, isOnline: true },
  { id: '2', name: 'Erişilebilirlik Grubu', lastMessage: 'Yeni etkinlik duyurusu yarın yapılacak.', time: '12:05', unreadCount: 0, isOnline: false },
  { id: '3', name: 'Ayşe Demir', lastMessage: 'Tamam, görüşürüz.', time: 'Dün', unreadCount: 5, isOnline: true },
  { id: '4', name: 'Mehmet Can', lastMessage: 'Dosyayı gönderdim.', time: 'Pazartesi', unreadCount: 0, isOnline: false },
];

// --- Components ---

const Header = ({ activeTab, setActiveTab }: { activeTab: string, setActiveTab: (tab: string) => void }) => {
  return (
    <header className="bg-surface text-text-main py-6 px-8 border-b border-border-dim sticky top-0 z-50">
      <div className="flex justify-between items-center mb-0">
        <h1 
          id="app-title"
          className="text-[32px] font-bold tracking-wider"
          aria-label="Blind Social Ana Sayfa"
        >
          Blind Social 
          <span className="ml-3 bg-highlight text-black text-[12px] font-extrabold px-2 py-1 rounded uppercase align-middle">
            A11Y Aktif
          </span>
        </h1>
        <div className="flex gap-6">
          <button 
            aria-label="Sohbetlerde ara"
            className="w-8 h-8 border-2 border-current rounded-md flex items-center justify-center hover:bg-white/10 transition-colors"
          >
            <Search size={20} />
          </button>
          <button 
            aria-label="Daha fazla seçenek"
            className="w-8 h-8 border-2 border-current rounded-md flex items-center justify-center hover:bg-white/10 transition-colors"
          >
            <MoreVertical size={20} />
          </button>
        </div>
      </div>
    </header>
  );
};

const Tabs = ({ activeTab, setActiveTab }: { activeTab: string, setActiveTab: (tab: string) => void }) => {
  return (
    <nav className="flex bg-surface border-b-4 border-border-dim" role="tablist">
      {[
        { id: 'chats', label: 'Sohbetler' },
        { id: 'blog', label: 'Blog' },
        { id: 'rooms', label: 'Odalar' },
      ].map((tab) => (
        <button
          key={tab.id}
          role="tab"
          aria-selected={activeTab === tab.id}
          aria-controls={`${tab.id}-panel`}
          id={`${tab.id}-tab`}
          onClick={() => setActiveTab(tab.id)}
          className={`flex-1 py-5 text-[18px] font-semibold uppercase transition-all relative border-b-4 ${
            activeTab === tab.id ? 'text-primary border-primary' : 'text-text-sub border-transparent'
          }`}
        >
          <span className="sr-only">{tab.label} sekmesi</span>
          {tab.label}
        </button>
      ))}
    </nav>
  );
};

const ChatItem = ({ chat }: { chat: Chat; key?: React.Key }) => {
  return (
    <button
      role="listitem"
      aria-label={`${chat.name} ile sohbet. Son mesaj: ${chat.lastMessage}. Saat: ${chat.time}. ${chat.unreadCount > 0 ? `${chat.unreadCount} okunmamış mesaj var.` : ''}`}
      className="w-full flex items-center gap-5 py-5 px-8 hover:bg-[#1a1a1a] transition-colors border-b border-border-dim text-left focus:outline-none focus:bg-[#1a1a1a] relative group"
    >
      <div className="relative">
        <div className="w-16 h-16 rounded-full bg-border-dim border-2 border-primary flex items-center justify-center text-text-main text-[28px] font-bold">
          {chat.name.split(' ').map(n => n[0]).join('')}
        </div>
        {chat.isOnline && (
          <div className="absolute bottom-0 right-0 w-4 h-4 bg-primary border-2 border-background rounded-full" />
        )}
      </div>
      
      <div className="flex-1 min-w-0">
        <div className="flex justify-between items-baseline mb-1">
          <h2 className="text-text-main text-[22px] font-bold">{chat.name}</h2>
          <span className="text-[16px] text-text-sub">
            {chat.time}
          </span>
        </div>
        <div className="flex justify-between items-center">
          <p className="text-text-sub text-[18px] truncate flex-1">
            {chat.lastMessage}
          </p>
          {chat.unreadCount > 0 && (
            <span className="bg-primary text-black text-[12px] font-extrabold min-w-[24px] h-6 flex items-center justify-center rounded-full px-1 ml-2">
              {chat.unreadCount}
            </span>
          )}
        </div>
      </div>
      <span className="absolute bottom-1 right-2 text-[10px] text-highlight opacity-70 font-mono sr-only md:not-sr-only">
        Semantics: {chat.name}
      </span>
    </button>
  );
};

const BottomNav = () => {
  return (
    <footer className="bg-surface border-top border-border-dim flex justify-around py-4 fixed bottom-0 left-0 right-0 z-50">
      {[
        { label: 'Ana Sayfa', icon: '🏠', active: true },
        { label: 'Aramalar', icon: '📞', active: false },
        { label: 'Profil', icon: '👤', active: false },
        { label: 'Ayarlar', icon: '⚙️', active: false },
      ].map((item, i) => (
        <div key={i} className={`flex flex-col items-center gap-1 ${item.active ? 'text-primary' : 'text-text-sub'}`}>
          <div className="w-8 h-8 border-2 border-current rounded-md flex items-center justify-center font-bold">
            {item.icon}
          </div>
          <span className="text-xs">{item.label}</span>
        </div>
      ))}
    </footer>
  );
};

export default function App() {
  const [activeTab, setActiveTab] = useState('chats');

  return (
    <div className="min-h-screen bg-background text-text-main font-sans selection:bg-primary/30 flex flex-col">
      <Header activeTab={activeTab} setActiveTab={setActiveTab} />
      <Tabs activeTab={activeTab} setActiveTab={setActiveTab} />

      <main className="flex-1 pb-32">
        <AnimatePresence mode="wait">
          {activeTab === 'chats' && (
            <motion.div
              key="chats"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              id="chats-panel"
              role="tabpanel"
              aria-labelledby="chats-tab"
            >
              <div role="list" className="flex flex-col">
                {MOCK_CHATS.map((chat) => (
                  <ChatItem key={chat.id} chat={chat} />
                ))}
              </div>
            </motion.div>
          )}

          {activeTab === 'blog' && (
            <motion.div
              key="blog"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              id="blog-panel"
              role="tabpanel"
              aria-labelledby="blog-tab"
              className="p-12 text-center"
            >
              <Rss size={64} className="mx-auto mb-6 text-text-sub opacity-20" />
              <h2 className="text-2xl font-bold mb-4">Blog İçeriği</h2>
              <p className="text-text-sub text-lg">Görme engelliler için güncel haberler ve makaleler burada listelenecek.</p>
            </motion.div>
          )}

          {activeTab === 'rooms' && (
            <motion.div
              key="rooms"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              id="rooms-panel"
              role="tabpanel"
              aria-labelledby="rooms-tab"
              className="p-12 text-center"
            >
              <Users size={64} className="mx-auto mb-6 text-text-sub opacity-20" />
              <h2 className="text-2xl font-bold mb-4">Sesli Odalar</h2>
              <p className="text-text-sub text-lg">Canlı sesli sohbet odalarına katılarak toplulukla etkileşime geçin.</p>
            </motion.div>
          )}
        </AnimatePresence>
      </main>

      <button
        aria-label="Yeni mesaj oluştur"
        className="fixed bottom-24 right-10 w-20 h-20 bg-primary text-black rounded-full shadow-[0_8px_24px_rgba(0,255,127,0.3)] flex items-center justify-center hover:scale-105 active:scale-95 transition-transform z-50 border-none text-4xl"
      >
        +
      </button>

      <BottomNav />

      <div className="sr-only" aria-live="polite">
        {activeTab === 'chats' && 'Sohbetler listesi yüklendi.'}
        {activeTab === 'blog' && 'Blog sayfası yüklendi.'}
        {activeTab === 'rooms' && 'Sesli odalar sayfası yüklendi.'}
      </div>
    </div>
  );
}
