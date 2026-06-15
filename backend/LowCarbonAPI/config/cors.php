<?php

return [

    // ตีกรอบเส้นทาง API ที่จะให้ CORS ทำงาน (เช่น api/*)
    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    // อนุญาตทุก HTTP method
    'allowed_methods' => ['*'],

    // อนุญาตทุก origin (สำหรับ dev)
    'allowed_origins' => ['*'],

    // ถ้าจะ lock origin จริง ๆ ก็ระบุ hostname แทน '*'
    // 'allowed_origins' => ['https://your-app.com'],

    // อนุญาตทุก header
    'allowed_headers' => ['*'],

    // เปิด/ปิด credential (cookie, authorization headers)
    'supports_credentials' => false,

    // ระยะเวลาที่ browser จะ cache preflight (วินาที)
    'max_age' => 0,

];
