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
  MessageCircle,
  Heart
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { createClient } from '@supabase/supabase-js';

// --- Supabase Config ---
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// Only initialize if keys are present
const supabase = (supabaseUrl && supabaseAnonKey) 
  ? createClient(supabaseUrl, supabaseAnonKey)
  : null;

// --- Mock Data fallback if no Supabase ---
const MOCK_POSTS = [
  { id: 'm1', content: 'Uygulamanızın önizlemesi hazır! Gerçek verileri görmek için lütfen ayarlar menüsünden Supabase anahtarlarınızı girin.', created_at: new Date().toISOString(), users: { username: 'Sistem' } },
  { id: 'm2', content: 'Blog sayfasında görme engelliler için erişilebilirlik ipuçları paylaşılacak.', created_at: new Date().toISOString(), users: { username: 'Erişilebilirlik' } },
];

const MOCK_CHATS = [
  { id: 'c1', name: 'Destek Ekibi', messages: [{ content: 'Hoş geldiniz! Size nasıl yardımcı olabiliriz?', created_at: new Date().toISOString() }], chat_participants: [{ user_id: 'demo-user', is_archived: false }] },
  { id: 'c2', name: 'Erişilebilirlik Topluluğu', messages: [{ content: 'Yarın saat 20:00\'de sesli oda etkinliğimiz var.', created_at: new Date().toISOString() }], chat_participants: [{ user_id: 'demo-user', is_archived: false }] },
];

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
    if (!supabase) {
      setUserId('demo-user');
      setChats(MOCK_CHATS);
      setPosts(MOCK_POSTS);
      setIsLoading(false);
      return;
    }

    // Check auth
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUserId(session?.user?.id || 'demo-user'); // Fallback to demo if not logged in
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUserId(session?.user?.id || 'demo-user');
    });

    return () => subscription.unsubscribe();
  }, []);

  const fetchData = async () => {
    if (!supabase || userId === 'demo-user') {
      setIsLoading(false);
      return;
    }
    
    setIsLoading(true);
    try {
      if (activeTab === 'chats') {
        const { data, error } = await supabase
          .from('chats')
          .select('*, chat_participants!inner(user_id, is_archived), messages(content, created_at)')
          .order('updated_at', { ascending: false })
          .limit(20);
        
        if (error) throw error;
        setChats(data || []);
      } else if (activeTab === 'blog') {
        const { data, error } = await supabase
          .from('posts')
          .select('*, users!posts_user_id_fkey(username)')
          .order('created_at', { ascending: false })
          .limit(10);
        
        if (error) throw error;
        setPosts(data || []);
      }
    } catch (err) {
      console.error('Data loading error:', err);
      // Fail gracefully to demo data if logged in but DB error occurs (e.g. table not ready)
      if (activeTab === 'chats') setChats(MOCK_CHATS);
      if (activeTab === 'blog') setPosts(MOCK_POSTS);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [activeTab, userId]);

  const toggleArchive = async (chatId: string, currentStatus: boolean) => {
    if (!supabase || userId === 'demo-user') {
      // Local UI update for demo
      setChats(prev => prev.map(c => 
        c.id === chatId 
          ? { ...c, chat_participants: c.chat_participants.map((p: any) => p.user_id === userId ? { ...p, is_archived: !currentStatus } : p) } 
          : c
      ));
      return;
    }
    
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

  const toggleLike = async (postId: string) => {
    if (!supabase || userId === 'demo-user') return;
    
    try {
      await supabase.rpc('toggle_post_like', { p_post_id: postId });
      fetchData();
    } catch (err) {
      console.error('Toggle like error:', err);
    }
  };

  return (
    <div className="min-h-screen bg-[#050505] text-white font-sans flex flex-col max-w-md mx-auto border-x border-[#333] shadow-2xl relative overflow-hidden">
      <Header 
        title={showArchived ? "Arşivlenmiş" : "Blind Social"} 
        onBack={showArchived ? () => setShowArchived(false) : undefined}
        onRefresh={fetchData}
        onSearch={() => {}}
      />
      
      {!showArchived && <Tabs activeTab={activeTab} setActiveTab={setActiveTab} />}

      <main className="flex-1 overflow-y-auto pb-20 scrollbar-hide">
        <div>
          {(!supabase || userId === 'demo-user') && activeTab === 'chats' && !showArchived && (
            <div className="bg-[#00FF7F]/10 p-3 text-xs text-[#00FF7F] text-center border-b border-[#00FF7F]/20">
              Gerçek verileri görmek için <strong>Settings</strong> menüsünden Supabase anahtarlarınızı tanımlayın.
            </div>
          )}
          {activeTab === 'chats' && (
            <div key="chats">
              
              {/* Archive Toggle Row */}
              {!showArchived && archivedCount > 0 && (
                <button 
                  onClick={() => setShowArchived(true)}
                  className="w-full flex items-center gap-4 px-4 py-4 hover:bg-white/5 border-b border-[#333] transition-colors"
                >
                  <Archive size={24} className="text-[#00FF7F]" />
                  <span className="flex-1 text-left font-bold">Arşivlenmiş</span>
                  <span className="text-sm bg-[#00FF7F]/20 text-[#00FF7F] px-2 py-0.5 rounded-full font-bold">
                    {archivedCount}
                  </span>
                </button>
              )}

              {isLoading ? (
                <div className="p-8 text-center text-gray-400">Yükleniyor...</div>
              ) : filteredChats.length === 0 ? (
                <div className="p-12 text-center text-gray-400">
                  <MessageCircle size={48} className="mx-auto mb-4 opacity-20" />
                  <p>{showArchived ? 'Arşivlenmiş sohbet yok.' : 'Henüz sohbetiniz yok.'}</p>
                </div>
              ) : (
                <div className="flex flex-col">
                  {filteredChats.map((chat) => (
                    <div 
                      key={chat.id}
                      className="flex items-center gap-4 px-4 py-3 hover:bg-white/5 border-b border-[#333] cursor-pointer group"
                    >
                      <div className="w-12 h-12 rounded-full bg-[#121212] border border-[#333] flex items-center justify-center font-bold text-lg">
                        {chat.name?.[0]?.toUpperCase() || 'S'}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex justify-between items-baseline mb-1">
                          <h3 className="font-bold truncate">{chat.name}</h3>
                          <span className="text-[10px] text-gray-500">
                            {chat.messages?.[0] ? new Date(chat.messages[0].created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                          </span>
                        </div>
                        <p className="text-sm text-gray-400 truncate">
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
            </div>
          )}

          {activeTab === 'blog' && (
            <div key="blog" className="p-4 space-y-4">
              {isLoading ? (
                <div className="p-8 text-center text-gray-400">Yükleniyor...</div>
              ) : posts.map((post) => (
                <div key={post.id} className="bg-[#121212] p-4 rounded-xl border border-[#333]">
                  <div className="flex justify-between items-start mb-2">
                    <span className="font-bold text-[#00FF7F]">{post.users?.username || 'Anonim'}</span>
                    <span className="text-[10px] text-gray-500">{new Date(post.created_at).toLocaleDateString()}</span>
                  </div>
                  <p className="text-sm leading-relaxed mb-3">{post.content}</p>
                  <div className="flex items-center gap-4 pt-2 border-t border-white/5">
                    <button 
                      onClick={() => toggleLike(post.id)}
                      className="flex items-center gap-1.5 text-xs text-gray-400 hover:text-red-500 transition-colors"
                    >
                      <Heart size={16} />
                      <span>{post.likes_count || 0} Beğeni</span>
                    </button>
                    <button className="text-xs text-gray-400 hover:text-[#00FF7F] transition-colors">
                      <MessageCircle size={16} className="inline mr-1" />
                      Yorum Yap
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}

          {activeTab === 'rooms' && (
            <div key="rooms" className="p-12 text-center text-gray-400">
              <Mic size={64} className="mx-auto mb-4 opacity-10" />
              <h3 className="text-lg font-bold mb-2">Sesli Odalar</h3>
              <p className="text-sm">Bu özellik şu an için sadece mobil uygulamada aktiftir.</p>
            </div>
          )}
        </div>
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
