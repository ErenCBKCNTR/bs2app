import 'package:flutter/material.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  // Geçici mock data (Mikro Blog sistemi tam aktif olana kadar)
  final List<Map<String, dynamic>> _mockPosts = [
    {
      'username': 'admin',
      'content': 'Blind Social\'a hoş geldiniz! Mikro blog özelliğimiz yakında tam sürümüyle aktif olacak.',
      'likes': 12,
      'time': '2 saat önce'
    },
    {
      'username': 'ahmet123',
      'content': 'Bugün erişilebilirlik konusunda çok güzel bir makale okudum. Sizlerle paylaşmak için sabırsızlanıyorum.',
      'likes': 5,
      'time': '5 saat önce'
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Mikro Blog sistemi şu an test aşamasındadır. Yakında kendi paylaşımlarınızı yapabileceksiniz!",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _mockPosts.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final post = _mockPosts[index];
              return Card(
                elevation: 0,
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.green.shade800,
                            child: Text(
                              post['username'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            post['username'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          Text(
                            post['time'],
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        post['content'],
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.favorite_border, size: 20, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(post['likes'].toString(), style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(width: 16),
                          Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text("0", style: TextStyle(color: Colors.grey.shade400)),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
