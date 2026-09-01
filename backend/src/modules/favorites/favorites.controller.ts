import { Controller, Delete, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { FavoritesService } from './favorites.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('favorites')
@ApiBearerAuth()
@Controller('favorites')
export class FavoritesController {
  constructor(private readonly favoritesService: FavoritesService) {}

  @Get()
  listMine(@CurrentUser('id') customerId: string) {
    return this.favoritesService.listMine(customerId);
  }

  @Post(':vendorId/toggle')
  toggle(@CurrentUser('id') customerId: string, @Param('vendorId', ParseUUIDPipe) vendorId: string) {
    return this.favoritesService.toggle(customerId, vendorId);
  }
}
