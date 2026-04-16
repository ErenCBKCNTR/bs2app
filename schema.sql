-- ==========================================
-- BLIND SOCIAL - SUPABASE VERİTABANI ŞEMASI
-- ==========================================
-- Bu dosyayı kopyalayıp Supabase SQL Editor'e yapıştırın ve çalıştırın.

-- 1. Kullanıcılar Tablosu (users)
-- Supabase Auth ile entegre çalışması için auth.users referans alınır.
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. Sohbetler Tablosu (chats)
-- Birebir veya grup sohbetlerini temsil eder.
CREATE TABLE IF NOT EXISTS public.chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    is_group BOOLEAN DEFAULT false,
    name TEXT, -- Sadece grup sohbetleri için
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 3. Sohbet Katılımcıları Tablosu (chat_participants)
-- Hangi kullanıcının hangi sohbette olduğunu tutar.
CREATE TABLE IF NOT EXISTS public.chat_participants (
    chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (chat_id, user_id)
);

-- 4. Mesajlar Tablosu (messages)
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLİTİKALARI
-- ==========================================

-- Tablolar için RLS'yi aktif et
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Users Politikaları
-- Herkes profilleri okuyabilir
CREATE POLICY "Kullanıcı profilleri herkes tarafından okunabilir" 
ON public.users FOR SELECT USING (true);

-- Kullanıcılar sadece kendi profillerini güncelleyebilir
CREATE POLICY "Kullanıcılar kendi profillerini güncelleyebilir" 
ON public.users FOR UPDATE USING (auth.uid() = id);

-- Chats Politikaları
-- Kullanıcılar sadece katılımcısı oldukları sohbetleri görebilir
CREATE POLICY "Kullanıcılar sadece kendi sohbetlerini görebilir" 
ON public.chats FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.chat_participants 
        WHERE chat_id = id AND user_id = auth.uid()
    )
);

-- Chat Participants Politikaları
-- Kullanıcılar sadece kendi sohbetlerindeki katılımcıları görebilir
CREATE POLICY "Kullanıcılar kendi sohbetlerindeki katılımcıları görebilir" 
ON public.chat_participants FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.chat_participants cp 
        WHERE cp.chat_id = chat_participants.chat_id AND cp.user_id = auth.uid()
    )
);

-- Messages Politikaları
-- Kullanıcılar sadece katılımcısı oldukları sohbetlerdeki mesajları görebilir
CREATE POLICY "Kullanıcılar kendi sohbetlerindeki mesajları görebilir" 
ON public.messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.chat_participants 
        WHERE chat_id = messages.chat_id AND user_id = auth.uid()
    )
);

-- Kullanıcılar sadece katılımcısı oldukları sohbetlere mesaj gönderebilir
CREATE POLICY "Kullanıcılar kendi sohbetlerine mesaj gönderebilir" 
ON public.messages FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.chat_participants 
        WHERE chat_id = messages.chat_id AND user_id = auth.uid()
    )
    AND sender_id = auth.uid() -- Mesajı gönderen kişi gerçekten giriş yapmış kişi olmalı
);

-- ==========================================
-- REALTIME (Gerçek Zamanlı) AYARLARI
-- ==========================================
-- Mesajlar ve katılımcılar tablosunu realtime dinlemeye aç
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
