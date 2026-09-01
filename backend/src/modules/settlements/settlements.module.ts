import { Module } from '@nestjs/common';
import { SettlementsController } from './settlements.controller';
import { WalletsService } from './wallets.service';
import { PayoutsService } from './payouts.service';
import { SettingsModule } from '../settings/settings.module';

@Module({
  controllers: [SettlementsController],
  providers: [WalletsService, PayoutsService],
  exports: [WalletsService],
})
export class SettlementsModule {}
