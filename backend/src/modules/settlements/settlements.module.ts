import { Module } from '@nestjs/common';
import { SettlementsController } from './settlements.controller';
import { CustomerWalletController } from './customer-wallet.controller';
import { CustomerWalletsService } from './customer-wallets.service';
import { WalletsService } from './wallets.service';
import { PayoutsService } from './payouts.service';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [SettingsModule],
  controllers: [SettlementsController, CustomerWalletController],
  providers: [WalletsService, PayoutsService, CustomerWalletsService],
  exports: [WalletsService, CustomerWalletsService],
})
export class SettlementsModule {}
