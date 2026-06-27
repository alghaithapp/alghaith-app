class ChatStickerPack {
  final String title;
  final List<String> stickers;

  const ChatStickerPack({
    required this.title,
    required this.stickers,
  });
}

class ChatStickers {
  ChatStickers._();

  static const packs = <ChatStickerPack>[
    ChatStickerPack(
      title: 'مشاعر',
      stickers: ['😀', '😂', '😍', '🥰', '😢', '😡', '😮', '🤔', '😴', '🤗'],
    ),
    ChatStickerPack(
      title: 'تفاعل',
      stickers: ['👍', '👎', '👏', '🙏', '💪', '🤝', '✌️', '🤞', '👌', '🫶'],
    ),
    ChatStickerPack(
      title: 'احتفال',
      stickers: ['🎉', '🎊', '🔥', '⭐', '💯', '🏆', '✨', '🎁', '🌹', '💐'],
    ),
    ChatStickerPack(
      title: 'طعام',
      stickers: ['☕', '🍕', '🍔', '🍰', '🍫', '🍉', '🍎', '🥗', '🍗', '🧃'],
    ),
  ];

  static List<String> get all =>
      packs.expand((pack) => pack.stickers).toList(growable: false);
}
