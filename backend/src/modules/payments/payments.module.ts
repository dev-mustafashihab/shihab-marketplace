import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { WalletsService } from '../settlements/wallets.service';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [SettingsModule],
  controllers: [PaymentsController],
  providers: [PaymentsService, WalletsService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
