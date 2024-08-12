/*
 * Nextcloud - Android Client
 *
 * SPDX-FileCopyrightText: 2024 Alper Ozturk <alper.ozturk@nextcloud.com>
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

package com.nextcloud.client.database.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import com.nextcloud.model.OfflineOperationType
import com.owncloud.android.db.ProviderMeta.ProviderTableMeta

@Entity(tableName = ProviderTableMeta.OFFLINE_OPERATION_TABLE_NAME)
data class OfflineOperationEntity(
    @PrimaryKey(autoGenerate = true)
    @ColumnInfo(name = ProviderTableMeta._ID)
    val id: Int? = null,

    @ColumnInfo(name = ProviderTableMeta.OFFLINE_OPERATION_PARENT_ID)
    val parentId: Int? = null,

    @ColumnInfo(name = ProviderTableMeta.OFFLINE_OPERATION_PARENT_OC_FILE_ID)
    val parentOCFileId: Long? = null,

    @ColumnInfo(name = ProviderTableMeta.OFFLINE_OPERATION_TYPE)
    val type: OfflineOperationType? = null,

    @ColumnInfo(name = ProviderTableMeta.OFFLINE_OPERATION_CREATED_AT)
    val createdAt: Long? = null,
)
