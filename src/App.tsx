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
    <header className="bg-surface text-text-main py-4 px-4 border-b border-border-dim sticky top-0 z-50">
      <div className="flex justify-between items-center">
        <h1 
          id="app-title"
          className="text-xl font-bold tracking-tight"
          aria-label="Blind Social Ana Sayfa"
        >
          Blind Social 
          <span className="ml-2 bg-highlight text-black text-[10px] font-extrabold px-1.5 py-0.5 rounded uppercase align-middle">
            A11Y
          </span>
        </h1>
        <div className="flex gap-4">
          <button 
            aria-label="Sohbetlerde ara"
            className="w-9 h-9 border border-current rounded-full flex items-center justify-center hover:bg-white/10 transition-colors"
          >
            <Search size={18} />
          </button>
          <button 
            aria-label="Daha fazla seçenek"
            className="w-9 h-9 border border-current rounded-full flex items-center justify-center hover:bg-white/10 transition-colors"
          >
            <MoreVertical size={18} />
          </button>
        </div>
      </div>
    </header>
  );
};

const Tabs = ({ activeTab, setActiveTab }: { activeTab: string, setActiveTab: (tab: string) => void }) => {
  return (
    <nav className="flex bg-surface border-b border-border-dim" role="tablist">
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
          className={`flex-1 py-3 text-sm font-bold uppercase transition-all relative border-b-2 ${
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
      className="w-full flex items-center gap-3 py-3 px-4 hover:bg-[#1a1a1a] transition-colors border-b border-border-dim text-left focus:outline-none focus:bg-[#1a1a1a] relative group"
    >
      <div className="relative">
        <div className="w-12 h-12 rounded-full bg-border-dim border border-primary/30 flex items-center justify-center text-text-main text-base font-bold">
          {chat.name.split(' ').map(n => n[0]).join('')}
        </div>
        {chat.isOnline && (
          <div className="absolute bottom-0.5 right-0.5 w-3 h-3 bg-primary border-2 border-background rounded-full" />
        )}
      </div>
      
      <div className="flex-1 min-w-0">
        <div className="flex justify-between items-baseline mb-0.5">
          <h2 className="text-text-main text-base font-semibold">{chat.name}</h2>
          <span className="text-xs text-text-sub">
            {chat.time}
          </span>
        </div>
        <div className="flex justify-between items-center">
          <p className="text-text-sub text-sm truncate flex-1">
            {chat.lastMessage}
          </p>
          {chat.unreadCount > 0 && (
            <span className="bg-primary text-black text-[10px] font-extrabold min-w-[18px] h-4.5 flex items-center justify-center rounded-full px-1 ml-2">
              {chat.unreadCount}
            </span>
          )}
        </div>
      </div>
    </button>
  );
};

const BottomNav = () => {
  return (
    <footer className="bg-surface border-t border-border-dim flex justify-around py-2 fixed bottom-0 left-0 right-0 z-50">
      {[
        { label: 'Ana Sayfa', icon: '🏠', active: true },
        { label: 'Aramalar', icon: '📞', active: false },
        { label: 'Profil', icon: '👤', active: false },
        { label: 'Ayarlar', icon: '⚙️', active: false },
      ].map((item, i) => (
        <div key={i} className={`flex flex-col items-center gap-0.5 ${item.active ? 'text-primary' : 'text-text-sub'}`}>
          <div className="w-7 h-7 border border-current rounded-md flex items-center justify-center font-bold text-sm">
            {item.icon}
          </div>
          <span className="text-[10px]">{item.label}</span>
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

      <main className="flex-1 pb-20">
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
              className="p-8 text-center"
            >
              <Rss size={48} className="mx-auto mb-4 text-text-sub opacity-20" />
              <h2 className="text-xl font-bold mb-2">Blog İçeriği</h2>
              <p className="text-text-sub text-sm">Görme engelliler için güncel haberler ve makaleler burada listelenecek.</p>
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
              className="p-8 text-center"
            >
              <Users size={48} className="mx-auto mb-4 text-text-sub opacity-20" />
              <h2 className="text-xl font-bold mb-2">Sesli Odalar</h2>
              <p className="text-text-sub text-sm">Canlı sesli sohbet odalarına katılarak toplulukla etkileşime geçin.</p>
            </motion.div>
          )}
        </AnimatePresence>
      </main>

      <button
        aria-label="Yeni mesaj oluştur"
        className="fixed bottom-20 right-6 w-14 h-14 bg-primary text-black rounded-full shadow-lg flex items-center justify-center hover:scale-105 active:scale-95 transition-transform z-50 border-none text-2xl"
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
