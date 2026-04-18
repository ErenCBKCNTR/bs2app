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
    dob DATE,
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
    is_archived BOOLEAN DEFAULT false, -- ARŞİVLEME SÜTUNU EKLENDİ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    created_by UUID DEFAULT auth.uid() REFERENCES public.users(id) -- OLUŞTURAN KİŞİ EKLENDİ (OTOMATİK ID ALIR)
);

-- Eğer chats tablosu önceden oluşturulduysa, sonradan sütun eklemek için çalıştırılması gereken komut:
-- (Hata verirse sütun zaten var demektir, görmezden gelebilirsiniz)
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;
ALTER TABLE public.chats ADD COLUMN IF NOT EXISTS created_by UUID DEFAULT auth.uid() REFERENCES public.users(id);

-- Eger tablo varsa ama auth.uid() default degeri verilmediyse onu kesin olarak verelim!
ALTER TABLE public.chats ALTER COLUMN created_by SET DEFAULT auth.uid();

-- 3. Sohbet Katılımcıları Tablosu (chat_participants)
-- Hangi kullanıcının hangi sohbette olduğunu tutar.
CREATE TABLE IF NOT EXISTS public.chat_participants (
    chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    last_read_message_id UUID, -- Okunmamış mesajları hesaplamak için
    is_archived BOOLEAN DEFAULT false, -- KİŞİSEL ARŞİVLEME SÜTUNU BURAYA TAŞINDI
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (chat_id, user_id)
);

ALTER TABLE public.chat_participants ADD COLUMN IF NOT EXISTS last_read_message_id UUID;
ALTER TABLE public.chat_participants ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;

-- Okunma durumu sorguları için performans indeksi
CREATE INDEX IF NOT EXISTS idx_chat_participants_last_read ON public.chat_participants(last_read_message_id);

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

-- ==========================================
-- RLS YARDIMCI FONKSİYONLARI (Infinite Recursion'ı Önlemek İçin)
-- ==========================================

-- Bu fonksiyon "kullanıcı bu sohbetin katılımcısı mı?" kontrolünü RLS döngüsüne girmeden yapar.
CREATE OR REPLACE FUNCTION public.is_chat_participant(chat_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_participants
    WHERE chat_participants.chat_id = $1
    AND chat_participants.user_id = auth.uid()
  );
$$;

-- Users Politikaları
-- Herkes profilleri okuyabilir
DROP POLICY IF EXISTS "Kullanıcı profilleri herkes tarafından okunabilir" ON public.users;
CREATE POLICY "Kullanıcı profilleri herkes tarafından okunabilir" 
ON public.users FOR SELECT USING (true);

-- Kullanıcılar sadece kendi profillerini güncelleyebilir
DROP POLICY IF EXISTS "Kullanıcılar kendi profillerini güncelleyebilir" ON public.users;
CREATE POLICY "Kullanıcılar kendi profillerini güncelleyebilir" 
ON public.users FOR UPDATE USING (auth.uid() = id);

-- Kullanıcılar kendi profillerini oluşturabilir (İlk kayıt aşaması için gerekli)
DROP POLICY IF EXISTS "Kullanıcılar kendi profillerini oluşturabilir" ON public.users;
CREATE POLICY "Kullanıcılar kendi profillerini oluşturabilir" 
ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- Chats Politikaları
-- Kullanıcılar sadece katılımcısı oldukları sohbetleri görebilir
DROP POLICY IF EXISTS "Kullanıcılar sadece kendi sohbetlerini görebilir" ON public.chats;
CREATE POLICY "Kullanıcılar sadece kendi sohbetlerini görebilir" 
ON public.chats FOR SELECT USING (
    public.is_chat_participant(id) OR created_by = auth.uid()
);

-- Kullanıcılar yeni sohbet oluşturabilir
DROP POLICY IF EXISTS "Kullanıcılar sohbet oluşturabilir" ON public.chats;
CREATE POLICY "Kullanıcılar sohbet oluşturabilir" 
ON public.chats FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Kullanıcılar oluşturdukları sohbetleri silebilir
DROP POLICY IF EXISTS "Kullanıcılar kendi sohbetlerini silebilir" ON public.chats;
CREATE POLICY "Kullanıcılar kendi sohbetlerini silebilir" 
ON public.chats FOR DELETE USING (created_by = auth.uid());

-- Chat Participants Politikaları
-- Kullanıcılar sadece kendi sohbetlerindeki katılımcıları görebilir
DROP POLICY IF EXISTS "Kullanıcılar kendi sohbetlerindeki katılımcıları görebilir" ON public.chat_participants;
CREATE POLICY "Kullanıcılar kendi sohbetlerindeki katılımcıları görebilir" 
ON public.chat_participants FOR SELECT USING (
    public.is_chat_participant(chat_id)
);

-- Kullanıcılar sohbetlere katılımcı ekleyebilir
DROP POLICY IF EXISTS "Kullanıcılar katılımcı ekleyebilir" ON public.chat_participants;
CREATE POLICY "Kullanıcılar katılımcı ekleyebilir" 
ON public.chat_participants FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Kullanıcılar kendi katılımcı bilgilerini güncelleyebilir (Arşivleme için)
DROP POLICY IF EXISTS "Kullanıcılar kendi katılımcı bilgilerini güncelleyebilir" ON public.chat_participants;
CREATE POLICY "Kullanıcılar kendi katılımcı bilgilerini güncelleyebilir" 
ON public.chat_participants FOR UPDATE USING (user_id = auth.uid());

-- Kullanıcılar kendi katılımcı bilgilerini silebilir (Sohbetten ayrılma/silme için)
DROP POLICY IF EXISTS "Kullanıcılar kendi katılımcı bilgilerini silebilir" ON public.chat_participants;
CREATE POLICY "Kullanıcılar kendi katılımcı bilgilerini silebilir" 
ON public.chat_participants FOR DELETE USING (user_id = auth.uid());

-- Messages Politikaları
-- Kullanıcılar sadece katılımcısı oldukları sohbetlerdeki mesajları görebilir
DROP POLICY IF EXISTS "Kullanıcılar kendi sohbetlerindeki mesajları görebilir" ON public.messages;
CREATE POLICY "Kullanıcılar kendi sohbetlerindeki mesajları görebilir" 
ON public.messages FOR SELECT USING (
    public.is_chat_participant(chat_id)
);

-- Kullanıcılar sadece katılımcısı oldukları sohbetlere mesaj gönderebilir
DROP POLICY IF EXISTS "Kullanıcılar kendi sohbetlerine mesaj gönderebilir" ON public.messages;
CREATE POLICY "Kullanıcılar kendi sohbetlerine mesaj gönderebilir" 
ON public.messages FOR INSERT WITH CHECK (
    public.is_chat_participant(chat_id)
    AND sender_id = auth.uid() -- Mesajı gönderen kişi gerçekten giriş yapmış kişi olmalı
);

-- ==========================================
-- REALTIME (Gerçek Zamanlı) AYARLARI
-- ==========================================
-- Mesajlar ve katılımcılar tablosunu realtime dinlemeye aç
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_participants;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ==========================================
-- MİKRO BLOG (POSTS) ve YORUMLAR AYARLARI
-- ==========================================
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    likes_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.post_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

-- Gönderi Politikaları
DROP POLICY IF EXISTS "Herkes gönderileri görebilir" ON public.posts;
CREATE POLICY "Herkes gönderileri görebilir" 
ON public.posts FOR SELECT USING (true);

DROP POLICY IF EXISTS "Giriş yapan kullanıcılar gönderi oluşturabilir" ON public.posts;
CREATE POLICY "Giriş yapan kullanıcılar gönderi oluşturabilir" 
ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Gönderi sahipleri gönderilerini güncelleyebilir" ON public.posts;
CREATE POLICY "Gönderi sahipleri gönderilerini güncelleyebilir" 
ON public.posts FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Gönderi sahipleri gönderilerini silebilir" ON public.posts;
CREATE POLICY "Gönderi sahipleri gönderilerini silebilir" 
ON public.posts FOR DELETE USING (auth.uid() = user_id);

-- Yorum Politikaları
DROP POLICY IF EXISTS "Herkes yorumları görebilir" ON public.post_comments;
CREATE POLICY "Herkes yorumları görebilir" 
ON public.post_comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Giriş yapan kullanıcılar yorum oluşturabilir" ON public.post_comments;
CREATE POLICY "Giriş yapan kullanıcılar yorum oluşturabilir" 
ON public.post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Yorum sahipleri yorumlarını güncelleyebilir" ON public.post_comments;
CREATE POLICY "Yorum sahipleri yorumlarını güncelleyebilir" 
ON public.post_comments FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Yorum sahipleri yorumlarını silebilir" ON public.post_comments;
CREATE POLICY "Yorum sahipleri yorumlarını silebilir" 
ON public.post_comments FOR DELETE USING (auth.uid() = user_id);

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.post_comments;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 5. Beğeniler Tablosu (post_likes)
CREATE TABLE IF NOT EXISTS public.post_likes (
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (post_id, user_id)
);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

-- Beğeni Politikaları
DROP POLICY IF EXISTS "Herkes beğenileri görebilir" ON public.post_likes;
CREATE POLICY "Herkes beğenileri görebilir" 
ON public.post_likes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Giriş yapan kullanıcılar beğeni yapabilir" ON public.post_likes;
CREATE POLICY "Giriş yapan kullanıcılar beğeni yapabilir" 
ON public.post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Kullanıcılar kendi beğenilerini silebilir" ON public.post_likes;
CREATE POLICY "Kullanıcılar kendi beğenilerini silebilir" 
ON public.post_likes FOR DELETE USING (auth.uid() = user_id);

-- Beğeniyi açıp kapatan fonksiyon (Toggle Like)
-- Bu fonksiyon beğeniyi ekler veya varsa siler ve likes_count'u günceller.
CREATE OR REPLACE FUNCTION public.toggle_post_like(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.post_likes WHERE post_id = p_post_id AND user_id = auth.uid()) THEN
        -- Beğeniyi kaldır
        DELETE FROM public.post_likes WHERE post_id = p_post_id AND user_id = auth.uid();
        -- Sayaç azalt
        UPDATE public.posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = p_post_id;
    ELSE
        -- Beğeni ekle
        INSERT INTO public.post_likes (post_id, user_id) VALUES (p_post_id, auth.uid());
        -- Sayaç artır
        UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = p_post_id;
    END IF;
END;
$$;

-- Realtime'a beğenileri de ekle
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.post_likes;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ==========================================
-- SESLİ ODALAR (VOICE ROOMS) - LIVEKIT İÇİN
-- ==========================================

-- 5. Sesli Odalar Tablosu (voice_rooms)
CREATE TABLE IF NOT EXISTS public.voice_rooms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 6. Sesli Oda Katılımcıları (voice_room_participants)
CREATE TABLE IF NOT EXISTS public.voice_room_participants (
    room_id UUID REFERENCES public.voice_rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (room_id, user_id)
);

-- Sesli Odalar RLS Politikaları
ALTER TABLE public.voice_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voice_room_participants ENABLE ROW LEVEL SECURITY;

-- Herkes aktif odaları görebilir
DROP POLICY IF EXISTS "Herkes aktif odaları görebilir" ON public.voice_rooms;
CREATE POLICY "Herkes aktif odaları görebilir" 
ON public.voice_rooms FOR SELECT USING (is_active = true);

-- Sadece giriş yapmış kullanıcılar oda oluşturabilir
DROP POLICY IF EXISTS "Kullanıcılar oda oluşturabilir" ON public.voice_rooms;
CREATE POLICY "Kullanıcılar oda oluşturabilir" 
ON public.voice_rooms FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Herkes odadaki katılımcıları görebilir
DROP POLICY IF EXISTS "Herkes oda katılımcılarını görebilir" ON public.voice_room_participants;
CREATE POLICY "Herkes oda katılımcılarını görebilir" 
ON public.voice_room_participants FOR SELECT USING (true);

-- Kullanıcılar odalara katılabilir
DROP POLICY IF EXISTS "Kullanıcılar odalara katılabilir" ON public.voice_room_participants;
CREATE POLICY "Kullanıcılar odalara katılabilir" 
ON public.voice_room_participants FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Kullanıcılar odalardan çıkabilir
DROP POLICY IF EXISTS "Kullanıcılar odalardan çıkabilir" ON public.voice_room_participants;
CREATE POLICY "Kullanıcılar odalardan çıkabilir" 
ON public.voice_room_participants FOR DELETE USING (auth.uid() = user_id);

-- Realtime'a sesli odaları da ekle
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_rooms;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_room_participants;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ==========================================
-- STORAGE (DOSYA DEPOLAMA) AYARLARI
-- ==========================================

-- chat_audio adında bir bucket oluşturulması (Eğer yoksa)
-- Not: Supabase arayüzünden Storage kısmına gidip "chat_audio" isimli PUBLIC bir bucket oluşturmayı da unutmayın, veya bu kodla otomatik oluşur.
INSERT INTO storage.buckets (id, name, public) VALUES ('chat_audio', 'chat_audio', true) ON CONFLICT (id) DO NOTHING;

-- Storage için RLS: Herkes okuyabilir, sadece giriş yapanlar yükleyebilir
DROP POLICY IF EXISTS "Sesli mesajları herkes okuyabilir" ON storage.objects;
CREATE POLICY "Sesli mesajları herkes okuyabilir" ON storage.objects FOR SELECT USING (bucket_id = 'chat_audio');

DROP POLICY IF EXISTS "Sadece giriş yapanlar sesli mesaj yükleyebilir" ON storage.objects;
CREATE POLICY "Sadece giriş yapanlar sesli mesaj yükleyebilir" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'chat_audio' AND auth.uid() = owner);

