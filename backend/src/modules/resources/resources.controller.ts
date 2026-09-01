import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { ResourcesService } from './resources.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

class CreateResourceDto {
  @IsString() @MinLength(2) @MaxLength(150) name!: string;

  @IsOptional() @IsEnum(['VENUE', 'STAFF', 'EQUIPMENT', 'OTHER'])
  type?: 'VENUE' | 'STAFF' | 'EQUIPMENT' | 'OTHER';

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) capacity?: number;
}

class UpdateResourceDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(150) name?: string;
  @IsOptional() @IsEnum(['VENUE', 'STAFF', 'EQUIPMENT', 'OTHER'])
  type?: 'VENUE' | 'STAFF' | 'EQUIPMENT' | 'OTHER';
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) capacity?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

@ApiTags('resources')
@ApiBearerAuth()
@Controller('resources')
export class ResourcesController {
  constructor(private readonly resourcesService: ResourcesService) {}

  @Get('mine')
  listMine(@CurrentUser() user: { id: string; role: string }) {
    return this.resourcesService.listMine(user);
  }

  @Post()
  create(
    @CurrentUser() user: { id: string; role: string },
    @Body() dto: CreateResourceDto,
  ) {
    return this.resourcesService.create(user, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateResourceDto,
  ) {
    return this.resourcesService.update(user, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: { id: string; role: string },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.resourcesService.remove(user, id);
  }
}
