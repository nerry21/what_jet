PATCH REBUILD — BOT ON/OFF END-TO-END
====================================

Isi patch ini:
- Toggle Bot ON/OFF dari Flutter ke Laravel.
- Saat admin kirim balasan manual, backend otomatis takeover dan mematikan bot sementara.
- Timer auto-resume 15 menit disimpan di tabel conversations.
- Inbound webhook akan mencoba mengaktifkan bot lagi bila timeout sudah lewat.
- Scheduler Laravel juga scan tiap menit, jadi bot bisa hidup lagi walau tidak ada request baru masuk.

FILE BACKEND
------------
- app/Services/Chatbot/BotAutomationToggleService.php
- app/Http/Controllers/Api/AdminMobile/BotControlController.php
- app/Services/Chatbot/AdminConversationMessageService.php
- app/Jobs/ProcessIncomingWhatsAppMessage.php
- app/Models/Conversation.php
- app/Http/Resources/AdminMobile/ConversationListItemResource.php
- app/Http/Resources/AdminMobile/ConversationDetailResource.php
- app/Jobs/ReactivateTimedOutBotConversationsJob.php
- app/Console/Commands/ReactivateTimedOutBotConversationsCommand.php
- routes/api.php
- routes/console.php
- database/migrations/2026_03_31_120000_add_bot_resume_columns_to_conversations_table.php

FILE FRONTEND
-------------
- lib/core/network/api_endpoints.dart
- lib/features/omnichannel/data/services/omnichannel_api_service.dart
- lib/features/omnichannel/data/repositories/omnichannel_repository.dart
- lib/features/omnichannel/data/models/omnichannel_conversation_detail_model.dart
- lib/features/omnichannel/presentation/widgets/omnichannel_center_pane.dart
- lib/features/omnichannel/presentation/pages/omnichannel_dashboard_page.dart

LANGKAH PASANG BACKEND
----------------------
1. Tempel file backend ke project Laravel Anda.
2. Jalankan:
   php artisan migrate
   php artisan optimize:clear
3. Pastikan worker jalan:
   php artisan queue:work
4. Pastikan cron scheduler aktif:
   * * * * * cd /home/u957356351/domains/spesial.online/public_html/chatbot_ai && php artisan schedule:run >> /dev/null 2>&1

LANGKAH PASANG FRONTEND
-----------------------
1. Tempel file frontend ke project Flutter Anda.
2. Jalankan:
   flutter clean
   flutter pub get
   flutter build apk --release --dart-define=API_BASE_URL=https://spesial.online

CATATAN
-------
- Patch ini dibangun ulang dari source zip yang Anda upload di percakapan ini.
- Saya sengaja memakai endpoint baru /bot-control agar tidak mengganggu reply endpoint yang sudah ada.
- Bila project Anda sudah berubah lagi setelah zip ini dibuat, mungkin perlu penyesuaian kecil.
