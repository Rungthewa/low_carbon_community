<?php
protected function schedule(Schedule $schedule)
{
    // รันทุกวัน 22:00
    $schedule->command('reducing:calculate')
             ->dailyAt('22:00')
             ->withoutOverlapping()
             ->onOneServer();
}
