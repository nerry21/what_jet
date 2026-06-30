import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConfig {
  const AppConfig._();

  static const String chatbotAiLocalBaseUrl = 'http://127.0.0.1:8000';
  static const String chatbotAiAndroidBaseUrl = 'http://10.0.2.2:8000';
  static const String chatbotAiProductionBaseUrl = 'https://spesial.online';

  static const String appTitle = 'WhatsApp';
  static const String businessDisplayName = 'JET Support';
  static const String businessSubtitle = 'Live Chat Customer Service';
  static const String currentUserLabel = 'Anda';
  static const String guestDisplayName = 'Pengguna Aplikasi';
  static const String sourceApp = 'what_jet_flutter';
  static const String preferredChannel = 'mobile_live_chat';

  static const Color green = Color(0xFF00A884);
  static const Color greenLight = Color(0xFF00D084);
  static const Color purple = Color(0xFF8764D5);
  static const Color purpleLight = Color(0xFFB784D5);
  static const Color softBackground = Color(0xFFF5F5F5);
  static const Color softBackgroundAlt = Color(0xFFE8E8E8);
  static const Color bubbleIncoming = Color(0xFFE5E5EA);
  static const Color bubbleOutgoing = Color(0xFFDCF8C6);
  static const Color bubbleOutgoingAlt = Color(0xFFB3E5FC);
  static const Color danger = Color(0xFFFF4757);
  static const Color success = Color(0xFF31A24C);
  static const Color mutedText = Color(0xFF65676B);
  static const Color subtleText = Color(0xFF999999);
  static const Color readReceipt = Color(0xFF53BDEB);

  static const Duration defaultPollingInterval = Duration(seconds: 3);
  static const Duration reconnectPollingInterval = Duration(seconds: 5);

  // BRIEF 2 — Format Teks WhatsApp di bubble (render-layer only).
  // Compile-time flag, default OFF. ON => bubble me-render *bold* / _italic_ /
  // ~strike~ / ```mono```. OFF => Text polos, visual/perilaku identik (0 delta).
  // Rollback = rebuild dengan nilai false / git revert (bukan toggle runtime).
  static const bool whatsappTextFormattingEnabled = true;

  // BRIEF 3A — Chat management (long-press action sheet + mark-unread).
  // Compile-time flag, default OFF. ON => long-press kartu/tile buka action
  // sheet "Tandai belum dibaca". OFF => onLongPress null, kartu/tile identik.
  // Rollback = rebuild dengan nilai false / git revert.
  static const bool chatManagementEnabled = true;

  // BRIEF 3F — Pencarian dalam-chat (in-chat message search).
  // Compile-time flag, default OFF. ON => ikon search di header (mobile+desktop)
  // buka search bar; pesan cocok disorot; ↑/↓ lompat antar-match (reuse
  // _scrollToMessage). OFF => nol ikon/bar/wrapper/state, runtime identik (0 delta).
  // Rollback = rebuild dengan nilai false / git revert.
  static const bool inChatSearchEnabled = true;

  // BRIEF 4A — Render stiker inbound (webp dari media.sticker_url).
  // Compile-time flag, default OFF. ON => stiker webp tampil (≈140px transparan)
  // di thread (2 layout); placeholder teks "[Stiker]" disembunyikan di body,
  // banner komposer, & quoted reply-preview => label "🩷 Stiker"; guard "-"
  // mengecualikan stiker. OFF => tampil teks "[Stiker]" dari BE (state lama, 0
  // delta). Rollback = rebuild false / git revert.
  static const bool stickerInboundEnabled = true;

  // BRIEF 4B-APP — Video outbound (kirim video admin->pelanggan).
  // Compile-time flag, default OFF. ON => entry "Video" muncul di attachment
  // tray (source picker Galeri/Kamera) -> guard 16MB UX -> multipart video_file.
  // OFF => entry "Video" tak dirender, tray identik lama (0 delta). Rollback =
  // rebuild false / git revert.
  static const bool videoOutboundEnabled = true;

  // BRIEF 4C-1-APP — Sticker resend (kirim ulang stiker diterima dari HP).
  // Compile-time flag, default OFF. ON => tombol overlay "kirim ulang" muncul di
  // preview stiker DITERIMA (!isMine) -> JSON reply {message_type:'sticker',
  // source_message_id}. OFF => tombol tak dirender, preview identik 4A (0 delta).
  // Rollback = rebuild false / git revert.
  static const bool stickerOutboundEnabled = true;

  // BRIEF 4C-2-APP — tombol "Simpan ke koleksi" di preview stiker DITERIMA
  // (!isMine). OFF => tombol tak dirender, preview identik 4C-1 (0 delta).
  // BE sticker-favorites sudah live. Rollback = rebuild false / git revert.
  static const bool stickerFavoritesEnabled = true;

  // BRIEF 4C-3-APP-1 — UI picker stiker favorit (grid favorit -> kirim).
  // Compile-time flag, default OFF (dark-launch). ON => tile "Stiker" muncul di
  // attachment sheet -> picker grid (GET favorit) -> tap kirim (POST
  // send-favorite). OFF => tile tak dirender (onStickerTap null), sheet identik
  // (0 delta). Aktivasi end-to-end butuh BE chatbot.whatsapp.sticker_picker_enabled
  // ON juga. Rollback = rebuild false / git revert.
  static const bool stickerPickerEnabled = true;

  // BRIEF 5C-APP-1 — Star/bintang pesan (render ikon + toggle long-press).
  // Compile-time flag, default OFF (dark-launch). ON => ikon bintang render di
  // bubble berbintang + aksi "Bintangi/Lepas bintang" muncul di long-press sheet.
  // OFF => ikon tak render, gesture identik lama (0 delta). Aktivasi end-to-end
  // butuh BE chatbot.whatsapp.message_star_enabled ON juga. Rollback = rebuild
  // false / git revert.
  static const bool messageStarEnabled = true;

  // BRIEF 5C-2-APP — Layar daftar "Pesan Berbintang" (read-only, lintas conv).
  // Compile-time flag, default OFF (dark-launch). ON => entry "Berbintang" di
  // bottom-nav mobile dashboard -> push layar daftar pesan berbintang. OFF =>
  // entry tak dirender, dashboard identik lama (0 delta). Aktivasi end-to-end
  // butuh BE message_star_enabled ON juga (sudah ON).
  // Rollback = rebuild false / git revert.
  static const bool starredListEnabled = true;

  // BRIEF 5A-FORWARD-APP — Teruskan pesan (menu long-press -> picker tujuan).
  // Compile-time flag, default OFF (dark-launch). ON => tile "Teruskan pesan"
  // muncul di long-press sheet (tipe forwardable saja) -> picker percakapan
  // tujuan (WhatsApp) -> POST forward. OFF => tile tak dirender, sheet identik
  // (0 delta). Catatan: sheet hanya terbuka saat messageStarEnabled ON (D-2).
  // Aktivasi = rebuild dgn true (BE endpoint sudah live).
  // Rollback = rebuild false / git revert.
  static const bool messageForwardEnabled = true;

  // BRIEF 6 — Compile-time flag, default OFF (dark-launch). ON => tile "Kirim
  // Daftar Rute" muncul di attachment sheet (WhatsApp only) -> POST send-carousel
  // -> BE kirim template carousel. OFF => tile tak dirender, sheet identik (0 delta).
  // Aktivasi = rebuild dgn true (BE flag + template Meta sudah live).
  // Rollback = rebuild false / git revert.
  static const bool routeCarouselEnabled = false;

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();

      if (host == 'localhost' || host == '127.0.0.1') {
        return chatbotAiLocalBaseUrl;
      }

      if (host.isNotEmpty) {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty) {
          return origin;
        }
      }

      return chatbotAiProductionBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // In release/profile mode, always use production URL.
      // The emulator-only 10.0.2.2 address is only useful during debug.
      if (kReleaseMode) {
        return chatbotAiProductionBaseUrl;
      }
      return chatbotAiAndroidBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (kReleaseMode) {
        return chatbotAiProductionBaseUrl;
      }
      return chatbotAiLocalBaseUrl;
    }

    return chatbotAiLocalBaseUrl;
  }

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: false,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: softBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        secondary: greenLight,
        surface: Colors.white,
      ),
    );
  }
}
