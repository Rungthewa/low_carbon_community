<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Http\Controllers\AppController; // เปลี่ยนเป็นคอนโทรลเลอร์จริง

class CalculateDailyReducing extends Command
{
    protected $signature = 'reducing:calculate {date?}';
    protected $description = 'Calculate & insert daily reducing for all activities (tree)';

    public function handle()
    {
        $date = $this->argument('date'); // optional: YYYY-MM-DD
        app(AppController::class)->calculateAndInsertDailyReducingWithCron($date);
        $this->info('Daily reducing calculated for ' . ($date ?: now()->toDateString()));
        return Command::SUCCESS;
    }
}

