import React, { useState, useEffect } from 'react';
import { 
  MessageSquare, 
  Users, 
  Rss, 
  Search, 
  MoreVertical, 
  Mic, 
  Plus,
  ArrowLeft,
  ChevronRight,
  Archive,
  RefreshCcw,
  LogOut,
  Send,
  MessageCircle
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { createClient } from '@supabase/supabase-js';

// --- Supabase Config ---
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';
const supabase = createClient(supabaseUrl, supabaseAnonKey);

// --- Components ---

const Header = ({ 
  title, 
  onBack, 
  onRefresh, 
  onSearch 
}: { 
  title: string, 
  onBack?: () => void, 
  onRefresh?: () => void,
  onSearch?: () => void
}) => {
  return (
    <header className="bg-surface text-text-main py-4 px-4 border-b border-border-dim sticky top-0 z-50">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          {onBack && (
            <button onClick={onBack} aria-label="Geri Dön" className="p-1 hover:bg-white/10 rounded-full">
              <ArrowLeft size={24} />
            </button>
          )}
          <h1 className="text-xl font-bold tracking-tight">{title}</h1>
        </div>
        <div className="flex gap-2">
          {onSearch && (
            <button onClick={onSearch} aria-label="Ara" className="w-9 h-9 flex items-center justify-center hover:bg-white/10 rounded-full">
              <Search size={20} />
            </button>
          )}
          {onRefresh && (
            <button onClick={onRefresh} aria-label="Yenile" className="w-9 h-9 flex items-center justify-center hover:bg-white/10 rounded-full">
              <RefreshCcw size={20} />
            </button>
          )}
          <button aria-label="Seçenekler" className="w-9 h-9 flex items-center justify-center hover:bg-white/10 rounded-full">
            <MoreVertical size={20} />
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
          onClick={() => setActiveTab(tab.id)}
          className={`flex-1 py-3 text-sm font-bold uppercase transition-all relative border-b-2 ${
            activeTab === tab.id ? 'text-primary border-primary' : 'text-text-sub border-transparent'
          }`}
        >
          {tab.label}
        </button>
      ))}
    </nav>
  );
};

export default function App() {
  const [activeTab, setActiveTab] = useState('chats');
  const [showArchived, setShowArchived] = useState(false);
  const [chats, setChats] = useState<any[]>([]);
  const [posts, setPosts] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [userId, setUserId] = useState<string | null>(null);

  useEffect(() => {
    // Check auth
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUserId(session?.user?.id || null);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChanged((_event, session) => {
      setUserId(session?.user?.id || null);
    });

    return () => subscription.unsubscribe();
  }, []);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      if (activeTab === 'chats') {
        const { data, error } = await supabase
          .from('chats')
          .select('*, chat_participants!inner(user_id, is_archived), messages(content, created_at)')
          .order('updated_at', { ascending: false });
        
        if (error) throw error;
        setChats(data || []);
      } else if (activeTab === 'blog') {
        const { data, error } = await supabase
          .from('posts')
          .select('*, users(username)')
          .order('created_at', { ascending: false });
        
        if (error) throw error;
        setPosts(data || []);
      }
    } catch (err) {
      console.error('Data loading error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [activeTab, userId]);

  const toggleArchive = async (chatId: string, currentStatus: boolean) => {
    if (!userId) return;
    try {
      await supabase
        .from('chat_participants')
        .update({ is_archived: !currentStatus })
        .match({ chat_id: chatId, user_id: userId });
      
      fetchData();
    } catch (err) {
      console.error('Archive toggle error:', err);
    }
  };

  const filteredChats = chats.filter(chat => {
    const myParticipant = chat.chat_participants?.find((p: any) => p.user_id === userId);
    const isArchived = myParticipant?.is_archived ?? false;
    return isArchived === showArchived;
  });

  const archivedCount = chats.filter(chat => {
    const p = chat.chat_participants?.find((p: any) => p.user_id === userId);
    return p?.is_archived === true;
  }).length;

  if (!userId) {
    return (
      <div className="min-h-screen bg-background text-text-main flex flex-col items-center justify-center p-6 text-center">
        <MessageSquare size={64} className="text-primary mb-6" />
        <h1 className="text-2xl font-bold mb-4">Blind Social'a Hoş Geldiniz</h1>
        <p className="text-text-sub mb-8">Uygulamayı önizlemek için lütfen backend bağlantınızı yapılandırın veya Flutter üzerinden test edin.</p>
        <div className="p-4 bg-surface rounded-lg border border-border-dim text-sm space-y-2">
          <p className="font-mono text-xs opacity-50">SUPABASE_URL ve SUPABASE_ANON_KEY eksik olabilir.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background text-text-main font-sans flex flex-col max-w-md mx-auto border-x border-border-dim">
      <Header 
        title={showArchived ? "Arşivlenmiş" : "Blind Social"} 
        onBack={showArchived ? () => setShowArchived(false) : undefined}
        onRefresh={fetchData}
        onSearch={() => {}}
      />
      
      {!showArchived && <Tabs activeTab={activeTab} setActiveTab={setActiveTab} />}

      <main className="flex-1 overflow-y-auto pb-20">
        <AnimatePresence mode="wait">
          {activeTab === 'chats' && (
            <motion.div key="chats" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
              
              {/* Archive Toggle Row */}
              {!showArchived && archivedCount > 0 && (
                <button 
                  onClick={() => setShowArchived(true)}
                  className="w-full flex items-center gap-4 px-4 py-4 hover:bg-white/5 border-b border-border-dim transition-colors"
                >
                  <Archive size={24} className="text-primary" />
                  <span className="flex-1 text-left font-bold">Arşivlenmiş</span>
                  <span className="text-sm bg-primary/20 text-primary px-2 py-0.5 rounded-full font-bold">
                    {archivedCount}
                  </span>
                </button>
              )}

              {isLoading ? (
                <div className="p-8 text-center text-text-sub">Yükleniyor...</div>
              ) : filteredChats.length === 0 ? (
                <div className="p-12 text-center text-text-sub">
                  <MessageCircle size={48} className="mx-auto mb-4 opacity-20" />
                  <p>{showArchived ? 'Arşivlenmiş sohbet yok.' : 'Henüz sohbetiniz yok.'}</p>
                </div>
              ) : (
                <div className="flex flex-col">
                  {filteredChats.map((chat) => (
                    <div 
                      key={chat.id}
                      className="flex items-center gap-4 px-4 py-3 hover:bg-white/5 border-b border-border-dim cursor-pointer group"
                    >
                      <div className="w-12 h-12 rounded-full bg-surface border border-border-dim flex items-center justify-center font-bold text-lg">
                        {chat.name?.[0]?.toUpperCase() || 'S'}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex justify-between items-baseline mb-1">
                          <h3 className="font-bold truncate">{chat.name}</h3>
                          <span className="text-[10px] text-text-sub">
                            {chat.messages?.[0] ? new Date(chat.messages[0].created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                          </span>
                        </div>
                        <p className="text-sm text-text-sub truncate">
                          {chat.messages?.[0]?.content || 'Resim veya mesaj yok'}
                        </p>
                      </div>
                      <button 
                        onClick={(e) => {
                          e.stopPropagation();
                          toggleArchive(chat.id, showArchived);
                        }}
                        className="p-2 opacity-0 group-hover:opacity-100 hover:bg-white/10 rounded-full transition-all"
                      >
                        <Archive size={18} />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </motion.div>
          )}

          {activeTab === 'blog' && (
            <motion.div key="blog" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="p-4 space-y-4">
              {isLoading ? (
                <div className="p-8 text-center text-text-sub">Yükleniyor...</div>
              ) : posts.map((post) => (
                <div key={post.id} className="bg-surface p-4 rounded-xl border border-border-dim">
                  <div className="flex justify-between items-start mb-2">
                    <span className="font-bold text-primary">{post.users?.username || 'Anonim'}</span>
                    <span className="text-[10px] text-text-sub">{new Date(post.created_at).toLocaleDateString()}</span>
                  </div>
                  <p className="text-sm leading-relaxed">{post.content}</p>
                </div>
              ))}
            </motion.div>
          )}

          {activeTab === 'rooms' && (
            <motion.div key="rooms" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="p-12 text-center text-text-sub">
              <Mic size={64} className="mx-auto mb-4 opacity-10" />
              <h3 className="text-lg font-bold mb-2">Sesli Odalar</h3>
              <p className="text-sm">Bu özellik şu an için sadece mobil uygulamada aktiftir.</p>
            </motion.div>
          )}
        </AnimatePresence>
      </main>

      <button className="fixed bottom-20 right-6 w-14 h-14 bg-primary text-black rounded-full shadow-lg flex items-center justify-center hover:scale-105 active:scale-95 transition-transform">
        <Plus size={32} />
      </button>

      <footer className="bg-surface border-t border-border-dim flex justify-around py-2 fixed bottom-0 left-0 right-0 max-w-md mx-auto">
        <div className="flex flex-col items-center gap-0.5 text-primary">
          <MessageSquare size={20} />
          <span className="text-[10px]">Mesajlar</span>
        </div>
        <div className="flex flex-col items-center gap-0.5 text-text-sub opacity-50">
          <Users size={20} />
          <span className="text-[10px]">Odalar</span>
        </div>
        <div className="flex flex-col items-center gap-0.5 text-text-sub opacity-50">
          <MoreVertical size={20} />
          <span className="text-[10px]">Profil</span>
        </div>
      </footer>
    </div>
  );
}
