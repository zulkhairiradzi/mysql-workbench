parser grammar MySQLParser;

/*
 * Copyright (c) 2012, 2018, Oracle and/or its affiliates. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2.0,
 * as published by the Free Software Foundation.
 *
 * This program is also distributed with certain software (including
 * but not limited to OpenSSL) that is licensed under separate terms, as
 * designated in a particular file or component or in included license
 * documentation. The authors of MySQL hereby grant you an additional
 * permission to link the program and your derivative works with the
 * separately licensed software that they have included with MySQL.
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
 * the GNU General Public License, version 2.0, for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */

/*
 * Merged in all changes up to mysql-trunk git revision [3179f4438b3] (13. March 2018).
 *
 * MySQL grammar for ANTLR 4.5+ with language features from MySQL 5.5.0 up to MySQL 8.0.
 * The server version in the generated parser can be switched at runtime, making it so possible
 * to switch the supported feature set dynamically.
 *
 * The coverage of the MySQL language should be 100%, but there might still be bugs or omissions.
 *
 * To use this grammar you will need a few support classes (which should be close to where you found this grammar).
 * These classes implement the target specific action code, so we don't clutter the grammar with that
 * and make it simpler to adjust it for other targets. See the demo/test project for further details.
 *
 * Written by Mike Lischke. Direct all bug reports, omissions etc. to mike.lischke@oracle.com.
 */

//-------------------------------------------------------------------------------------------------

// $antlr-format alignTrailingComments on, columnLimit 130, minEmptyLines 1, maxEmptyLinesToKeep 1, reflowComments off
// $antlr-format  useTab off, allowShortRulesOnASingleLine off, allowShortBlocksOnASingleLine on, alignSemicolons ownLine

options {
    superClass = MySQLBaseRecognizer;
    tokenVocab = MySQLLexer;
    exportMacro = PARSERS_PUBLIC_TYPE;
}

//-------------------------------------------------------------------------------------------------

@header {/*
 * Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2.0,
 * as published by the Free Software Foundation.
 *
 * This program is also distributed with certain software (including
 * but not limited to OpenSSL) that is licensed under separate terms, as
 * designated in a particular file or component or in included license
 * documentation. The authors of MySQL hereby grant you an additional
 * permission to link the program and your derivative works with the
 * separately licensed software that they have included with MySQL.
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See
 * the GNU General Public License, version 2.0, for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */
}

@postinclude {
#include "MySQLBaseRecognizer.h"
}

//-------------------------------------------------------------------------------------------------

query:
    EOF
    | (simpleStatement | beginWork) (SEMICOLON_SYMBOL EOF? | EOF)
;

simpleStatement:
    // DDL
    alterStatement
    | createStatement
    | dropStatement
    | renameTableStatement
    | truncateTableStatement
    | {serverVersion >= 80000}? importStatement

    // DML
    | callStatement
    | deleteStatement
    | doStatement
    | handlerStatement
    | insertStatement
    | loadStatement
    | replaceStatement
    | selectStatement
    | updateStatement
    | transactionOrLockingStatement
    | replicationStatement
    | preparedStatement

    // Data Directory
    | {serverVersion >= 80000}? cloneStatement

    // Database administration
    | accountManagementStatement
    | tableAdministrationStatement
    | installUninstallStatment
    | setStatement // SET PASSWORD is handled in accountManagementStatement.
    | showStatement
    | {serverVersion >= 80000}? resourceGroupManagement
    | otherAdministrativeStatement

    // MySQL utilitity statements
    | utilityStatement
    | {serverVersion >= 50604}? getDiagnostics
    | {serverVersion >= 50500}? signalStatement
    | {serverVersion >= 50500}? resignalStatement
;

//----------------- DDL statements -----------------------------------------------------------------

alterStatement:
    ALTER_SYMBOL (
        alterTable
        | alterDatabase
        | PROCEDURE_SYMBOL procedureRef routineAlterOptions?
        | FUNCTION_SYMBOL functionRef routineAlterOptions?
        | alterView
        | alterEvent
        | alterTablespace
        | alterLogfileGroup
        | alterServer
        // ALTER USER is part of the user management rule.
        | {serverVersion >= 50713}? INSTANCE_SYMBOL ROTATE_SYMBOL textOrIdentifier MASTER_SYMBOL KEY_SYMBOL
    )
;

alterDatabase:
    DATABASE_SYMBOL schemaRef (
        createDatabaseOption+
        | {serverVersion < 80000}? UPGRADE_SYMBOL DATA_SYMBOL DIRECTORY_SYMBOL NAME_SYMBOL
    )
;

alterEvent:
    definerClause? EVENT_SYMBOL eventRef (ON_SYMBOL SCHEDULE_SYMBOL schedule)? (
        ON_SYMBOL COMPLETION_SYMBOL NOT_SYMBOL? PRESERVE_SYMBOL
    )? (RENAME_SYMBOL TO_SYMBOL identifier)? (
        ENABLE_SYMBOL
        | DISABLE_SYMBOL (ON_SYMBOL SLAVE_SYMBOL)?
    )? (COMMENT_SYMBOL textLiteral)? (DO_SYMBOL compoundStatement)?
;

alterLogfileGroup:
    LOGFILE_SYMBOL GROUP_SYMBOL logfileGroupRef ADD_SYMBOL UNDOFILE_SYMBOL textLiteral alterLogfileGroupOptions?
;

alterLogfileGroupOptions:
    alterLogfileGroupOption (COMMA_SYMBOL? alterLogfileGroupOption)*
;

alterLogfileGroupOption:
    option = INITIAL_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | STORAGE_SYMBOL? option = ENGINE_SYMBOL EQUAL_OPERATOR? engineRef
    | option = (WAIT_SYMBOL | NO_WAIT_SYMBOL)
;

alterServer:
    SERVER_SYMBOL serverRef serverOptions
;

alterTable:
    onlineOption? ({serverVersion < 50700}? IGNORE_SYMBOL)? TABLE_SYMBOL tableRef alterTableActions?
;

alterTableActions:
    alterCommandList (partitionClause | removePartitioning)?
    | partitionClause
    | removePartitioning
    | (alterCommandsModifierList COMMA_SYMBOL)? standaloneAlterCommands
;

alterCommandList:
    alterCommandsModifierList
    | (alterCommandsModifierList COMMA_SYMBOL)? alterList
;

alterCommandsModifierList:
    alterCommandsModifier (COMMA_SYMBOL alterCommandsModifier)*
;

standaloneAlterCommands:
    DISCARD_SYMBOL TABLESPACE_SYMBOL
    | IMPORT_SYMBOL TABLESPACE_SYMBOL
    | alterPartition
;

alterPartition:
    ADD_SYMBOL PARTITION_SYMBOL noWriteToBinLog? (
        partitionDefinitions
        | PARTITIONS_SYMBOL real_ulong_number
    )
    | DROP_SYMBOL PARTITION_SYMBOL identifierList
    | REBUILD_SYMBOL PARTITION_SYMBOL noWriteToBinLog? allOrPartitionNameList

    // yes, twice "no write to bin log".
    | OPTIMIZE_SYMBOL PARTITION_SYMBOL noWriteToBinLog? allOrPartitionNameList noWriteToBinLog?
    | ANALYZE_SYMBOL PARTITION_SYMBOL noWriteToBinLog? allOrPartitionNameList
    | CHECK_SYMBOL PARTITION_SYMBOL allOrPartitionNameList checkOption*
    | REPAIR_SYMBOL PARTITION_SYMBOL noWriteToBinLog? allOrPartitionNameList repairType*
    | COALESCE_SYMBOL PARTITION_SYMBOL noWriteToBinLog? real_ulong_number
    | {serverVersion >= 50500}? TRUNCATE_SYMBOL PARTITION_SYMBOL allOrPartitionNameList
    | reorgPartitionRule
    | REORGANIZE_SYMBOL PARTITION_SYMBOL noWriteToBinLog? (
        identifierList INTO_SYMBOL partitionDefinitions
    )?
    | EXCHANGE_SYMBOL PARTITION_SYMBOL identifier WITH_SYMBOL TABLE_SYMBOL tableRef withValidation?
    | {serverVersion >= 50704}? DISCARD_SYMBOL PARTITION_SYMBOL allOrPartitionNameList TABLESPACE_SYMBOL
    | {serverVersion >= 50704}? IMPORT_SYMBOL PARTITION_SYMBOL allOrPartitionNameList TABLESPACE_SYMBOL
;

alterList:
    (alterListItem | createTableOptionsSpaceSeparated) (
        COMMA_SYMBOL (
            alterListItem
            | alterCommandsModifier
            | createTableOptionsSpaceSeparated
        )
    )*
;

alterCommandsModifier:
    {serverVersion >= 50600}? alterAlgorithmOption
    | {serverVersion >= 50600}? alterLockOption
    | withValidation
;

alterListItem:
    ADD_SYMBOL COLUMN_SYMBOL? (
        identifier fieldDefinition checkOrReferences? place?
        | OPEN_PAR_SYMBOL tableElementList CLOSE_PAR_SYMBOL
    )
    | ADD_SYMBOL tableConstraintDef
    | CHANGE_SYMBOL COLUMN_SYMBOL? columnInternalRef identifier fieldDefinition place?
    | MODIFY_SYMBOL COLUMN_SYMBOL? columnInternalRef fieldDefinition place?
    | DROP_SYMBOL (
        COLUMN_SYMBOL? columnInternalRef restrict?
        | FOREIGN_SYMBOL KEY_SYMBOL (
            // This part is no longer optional starting with 5.7.
            {serverVersion >= 50700}? columnInternalRef
            | {serverVersion < 50700}? columnInternalRef?
        )
        | PRIMARY_SYMBOL KEY_SYMBOL
        | keyOrIndex indexRef
    )
    | DISABLE_SYMBOL KEYS_SYMBOL
    | ENABLE_SYMBOL KEYS_SYMBOL
    | ALTER_SYMBOL COLUMN_SYMBOL? columnInternalRef (
        SET_SYMBOL DEFAULT_SYMBOL signedLiteral
        | DROP_SYMBOL DEFAULT_SYMBOL
    )
    | {serverVersion >= 80000}? ALTER_SYMBOL INDEX_SYMBOL indexRef visibility
    | RENAME_SYMBOL (TO_SYMBOL | AS_SYMBOL)? tableName
    | {serverVersion >= 50700}? RENAME_SYMBOL keyOrIndex indexRef TO_SYMBOL indexName
    | CONVERT_SYMBOL TO_SYMBOL charset charsetName (COLLATE_SYMBOL collationName)?
    | FORCE_SYMBOL
    | ORDER_SYMBOL BY_SYMBOL alterOrderList
    | {serverVersion >= 50708 && serverVersion < 80000}? UPGRADE_SYMBOL PARTITIONING_SYMBOL
;

place:
    AFTER_SYMBOL identifier
    | FIRST_SYMBOL
;

restrict:
    RESTRICT_SYMBOL
    | CASCADE_SYMBOL
;

alterOrderList:
    identifier direction (COMMA_SYMBOL identifier direction)*
;

alterAlgorithmOption:
    ALGORITHM_SYMBOL EQUAL_OPERATOR? (DEFAULT_SYMBOL | identifier)
;

alterLockOption:
    LOCK_SYMBOL EQUAL_OPERATOR? (DEFAULT_SYMBOL | identifier)
;

indexLockAndAlgorithm:
    {serverVersion >= 50600}? (
        alterAlgorithmOption alterLockOption?
        | alterLockOption alterAlgorithmOption?
    )
;

withValidation:
    {serverVersion >= 50706}? (WITH_SYMBOL | WITHOUT_SYMBOL) VALIDATION_SYMBOL
;

removePartitioning:
    REMOVE_SYMBOL PARTITIONING_SYMBOL
;

allOrPartitionNameList:
    ALL_SYMBOL
    | identifierList
;

reorgPartitionRule:
    REORGANIZE_SYMBOL PARTITION_SYMBOL noWriteToBinLog? (
        identifierList INTO_SYMBOL partitionDefinitions
    )?
;

alterTablespace:
    TABLESPACE_SYMBOL tablespaceRef (
        (ADD_SYMBOL | DROP_SYMBOL) DATAFILE_SYMBOL textLiteral (
            alterTablespaceOption (COMMA_SYMBOL? alterTablespaceOption)*
        )?
        // The alternatives listed below are not documented but appear in the server grammar file.
        | {serverVersion < 80000}? (
            | CHANGE_SYMBOL DATAFILE_SYMBOL textLiteral (
                changeTablespaceOption (COMMA_SYMBOL? changeTablespaceOption)*
            )?
            | (READ_ONLY_SYMBOL | READ_WRITE_SYMBOL)
            | NOT_SYMBOL ACCESSIBLE_SYMBOL
        )
        | RENAME_SYMBOL TO_SYMBOL identifier
    )
;

alterTablespaceOption:
    INITIAL_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | AUTOEXTEND_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | MAX_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | STORAGE_SYMBOL? ENGINE_SYMBOL EQUAL_OPERATOR? engineRef
    | (WAIT_SYMBOL | NO_WAIT_SYMBOL)
;

changeTablespaceOption:
    INITIAL_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | AUTOEXTEND_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | MAX_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
;

alterView:
    viewAlgorithm? definerClause? viewSuid? VIEW_SYMBOL viewRef viewTail
;

// This is not the full view_tail from sql_yacc.yy as we have either a view name or a view reference,
// depending on whether we come from createView or alterView. Everything until this difference is duplicated in those rules.
viewTail:
    columnInternalRefList? AS_SYMBOL viewSelect
;

viewSelect:
    queryExpressionOrParens viewCheckOption?
;

viewCheckOption:
    WITH_SYMBOL (CASCADED_SYMBOL | LOCAL_SYMBOL)? CHECK_SYMBOL OPTION_SYMBOL
;

//--------------------------------------------------------------------------------------------------

createStatement:
    createDatabase
    | createTable
    | createFunction
    | createProcedure
    | createUdf
    | createLogfileGroup
    | createView
    | createTrigger
    | createIndex
    | createServer
    | createTablespace
    | createEvent
    | {serverVersion >= 80000}? createRole
    | {serverVersion >= 80011}? createSpatialReference
;

createDatabase:
    CREATE_SYMBOL DATABASE_SYMBOL ifNotExists? schemaName createDatabaseOption*
;

createDatabaseOption:
    defaultCharset
    | defaultCollation
;

createTable:
    CREATE_SYMBOL TEMPORARY_SYMBOL? TABLE_SYMBOL ifNotExists? tableName (
        (OPEN_PAR_SYMBOL tableElementList CLOSE_PAR_SYMBOL)? createTableOptions? partitionClause? duplicateAsQueryExpression?
        | LIKE_SYMBOL tableRef
        | OPEN_PAR_SYMBOL LIKE_SYMBOL tableRef CLOSE_PAR_SYMBOL
    )
;

tableElementList:
    tableElement (COMMA_SYMBOL tableElement)*
;

tableElement:
    columnDefinition
    | tableConstraintDef
;

duplicateAsQueryExpression: (REPLACE_SYMBOL | IGNORE_SYMBOL)? AS_SYMBOL? queryExpressionOrParens
;

queryExpressionOrParens:
    queryExpression
    | queryExpressionParens
;

createWithDefiner:
    CREATE_SYMBOL definerClause?
;

createRoutine: // Rule for external use only.
    (createProcedure | createFunction | createUdf) SEMICOLON_SYMBOL? EOF
;

createProcedure:
    createWithDefiner PROCEDURE_SYMBOL procedureName OPEN_PAR_SYMBOL (
        procedureParameter (COMMA_SYMBOL procedureParameter)*
    )? CLOSE_PAR_SYMBOL routineCreateOption* compoundStatement
;

createFunction:
    createWithDefiner FUNCTION_SYMBOL functionName OPEN_PAR_SYMBOL (
        functionParameter (COMMA_SYMBOL functionParameter)*
    )? CLOSE_PAR_SYMBOL RETURNS_SYMBOL typeWithOptCollate routineCreateOption* compoundStatement
;

createUdf:
    CREATE_SYMBOL AGGREGATE_SYMBOL? FUNCTION_SYMBOL udfName RETURNS_SYMBOL type = (
        STRING_SYMBOL
        | INT_SYMBOL
        | REAL_SYMBOL
        | DECIMAL_SYMBOL
    ) SONAME_SYMBOL textLiteral
;

routineCreateOption:
    routineOption
    | NOT_SYMBOL? DETERMINISTIC_SYMBOL
;

routineAlterOptions:
    routineCreateOption+
;

routineOption:
    option = COMMENT_SYMBOL textLiteral
    | option = LANGUAGE_SYMBOL SQL_SYMBOL
    | option = NO_SYMBOL SQL_SYMBOL
    | option = CONTAINS_SYMBOL SQL_SYMBOL
    | option = READS_SYMBOL SQL_SYMBOL DATA_SYMBOL
    | option = MODIFIES_SYMBOL SQL_SYMBOL DATA_SYMBOL
    | option = SQL_SYMBOL SECURITY_SYMBOL security = (
        DEFINER_SYMBOL
        | INVOKER_SYMBOL
    )
;

createIndex:
    CREATE_SYMBOL onlineOption? (
        UNIQUE_SYMBOL? type = INDEX_SYMBOL indexNameAndType? createIndexTarget indexOption*
        | type = FULLTEXT_SYMBOL INDEX_SYMBOL indexName createIndexTarget fulltextIndexOption*
        | type = SPATIAL_SYMBOL INDEX_SYMBOL indexName createIndexTarget spatialIndexOption*
    ) indexLockAndAlgorithm?
;

/*
  The syntax for defining an index is:

    ... INDEX [index_name] [USING|TYPE] <index_type> ...

  The problem is that whereas USING is a reserved word, TYPE is not. We can
  still handle it if an index name is supplied, i.e.:

    ... INDEX type TYPE <index_type> ...

  here the index's name is unmbiguously 'type', but for this:

    ... INDEX TYPE <index_type> ...

  it's impossible to know what this actually mean - is 'type' the name or the
  type? For this reason we accept the TYPE syntax only if a name is supplied.
*/
indexNameAndType:
    indexName (USING_SYMBOL indexType)?
    | indexName TYPE_SYMBOL indexType
;

createIndexTarget:
    ON_SYMBOL tableRef keyList
;

createLogfileGroup:
    CREATE_SYMBOL LOGFILE_SYMBOL GROUP_SYMBOL logfileGroupName ADD_SYMBOL (
        UNDOFILE_SYMBOL
        | REDOFILE_SYMBOL // No longer used from 8.0 onwards. Taken out by lexer.
    ) textLiteral logfileGroupOptions?
;

logfileGroupOptions:
    logfileGroupOption (COMMA_SYMBOL? logfileGroupOption)*
;

logfileGroupOption:
    option = INITIAL_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | option = (UNDO_BUFFER_SIZE_SYMBOL | REDO_BUFFER_SIZE_SYMBOL) EQUAL_OPERATOR? sizeNumber
    | option = NODEGROUP_SYMBOL EQUAL_OPERATOR? real_ulong_number
    | STORAGE_SYMBOL? option = ENGINE_SYMBOL EQUAL_OPERATOR? engineRef
    | option = (WAIT_SYMBOL | NO_WAIT_SYMBOL)
    | option = COMMENT_SYMBOL EQUAL_OPERATOR? textLiteral
;

createServer:
    CREATE_SYMBOL SERVER_SYMBOL serverName FOREIGN_SYMBOL DATA_SYMBOL WRAPPER_SYMBOL textOrIdentifier serverOptions
;

serverOptions:
    OPTIONS_SYMBOL OPEN_PAR_SYMBOL serverOption (COMMA_SYMBOL serverOption)* CLOSE_PAR_SYMBOL
;

// Options for CREATE/ALTER SERVER, used for the federated storage engine.
serverOption:
    option = HOST_SYMBOL textLiteral
    | option = DATABASE_SYMBOL textLiteral
    | option = USER_SYMBOL textLiteral
    | option = PASSWORD_SYMBOL textLiteral
    | option = SOCKET_SYMBOL textLiteral
    | option = OWNER_SYMBOL textLiteral
    | option = PORT_SYMBOL ulong_number
;

createTablespace:
    CREATE_SYMBOL TABLESPACE_SYMBOL tablespaceName ADD_SYMBOL DATAFILE_SYMBOL textLiteral (
        USE_SYMBOL LOGFILE_SYMBOL GROUP_SYMBOL logfileGroupRef
    )? tablespaceOptions?
;

tablespaceOptions:
    tablespaceOption (COMMA_SYMBOL? tablespaceOption)*
;

tablespaceOption:
    option = INITIAL_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | option = AUTOEXTEND_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | option = MAX_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | option = EXTENT_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
    | option = NODEGROUP_SYMBOL EQUAL_OPERATOR? real_ulong_number
    | STORAGE_SYMBOL? option = ENGINE_SYMBOL EQUAL_OPERATOR? engineRef
    | option = (WAIT_SYMBOL | NO_WAIT_SYMBOL)
    | option = COMMENT_SYMBOL EQUAL_OPERATOR? textLiteral
    | {serverVersion >= 50707}? option = FILE_BLOCK_SIZE_SYMBOL EQUAL_OPERATOR? sizeNumber
;

createView:
    CREATE_SYMBOL viewReplaceOrAlgorithm? definerClause? viewSuid? VIEW_SYMBOL viewName viewTail
;

viewReplaceOrAlgorithm:
    OR_SYMBOL REPLACE_SYMBOL viewAlgorithm?
    | viewAlgorithm
;

viewAlgorithm:
    ALGORITHM_SYMBOL EQUAL_OPERATOR algorithm = (
        UNDEFINED_SYMBOL
        | MERGE_SYMBOL
        | TEMPTABLE_SYMBOL
    )
;

viewSuid:
    SQL_SYMBOL SECURITY_SYMBOL (DEFINER_SYMBOL | INVOKER_SYMBOL)
;

createTrigger:
    createWithDefiner TRIGGER_SYMBOL triggerName timing = (
        BEFORE_SYMBOL
        | AFTER_SYMBOL
    ) event = (INSERT_SYMBOL | UPDATE_SYMBOL | DELETE_SYMBOL) ON_SYMBOL tableRef FOR_SYMBOL EACH_SYMBOL ROW_SYMBOL
        triggerFollowsPrecedesClause? compoundStatement
;

triggerFollowsPrecedesClause:
    {serverVersion >= 50700}? ordering = (FOLLOWS_SYMBOL | PRECEDES_SYMBOL) textOrIdentifier // not a trigger reference!
;

createEvent:
    createWithDefiner EVENT_SYMBOL ifNotExists? eventName ON_SYMBOL SCHEDULE_SYMBOL schedule (
        ON_SYMBOL COMPLETION_SYMBOL NOT_SYMBOL? PRESERVE_SYMBOL
    )? (ENABLE_SYMBOL | DISABLE_SYMBOL (ON_SYMBOL SLAVE_SYMBOL)?)? (
        COMMENT_SYMBOL textLiteral
    )? DO_SYMBOL compoundStatement
;

createRole:
    // The server grammar has a clear_privileges rule here, which is only used to clear internal state.
    CREATE_SYMBOL ROLE_SYMBOL ifNotExists? roleList
;

createSpatialReference:
    CREATE_SYMBOL OR_SYMBOL REPLACE_SYMBOL SPATIAL_SYMBOL REFERENCE_SYMBOL SYSTEM_SYMBOL real_ulonglong_number srsAttribute*
    | CREATE_SYMBOL SPATIAL_SYMBOL REFERENCE_SYMBOL SYSTEM_SYMBOL ifNotExists? real_ulonglong_number srsAttribute*
;

srsAttribute:
    NAME_SYMBOL TEXT_SYMBOL textStringNoLinebreak
    | DEFINITION_SYMBOL TEXT_SYMBOL textStringNoLinebreak
    | ORGANIZATION_SYMBOL textStringNoLinebreak IDENTIFIED_SYMBOL BY_SYMBOL real_ulonglong_number
    | DESCRIPTION_SYMBOL TEXT_SYMBOL textStringNoLinebreak
;

//--------------------------------------------------------------------------------------------------

dropStatement:
    dropDatabase
    | dropEvent
    | dropFunction
    | dropProcedure
    | dropIndex
    | dropLogfileGroup
    | dropServer
    | dropTable
    | dropTableSpace
    | dropTrigger
    | dropView
    | {serverVersion >= 80000}? dropRole
    | {serverVersion >= 80011}? dropSpatialReference
;

dropDatabase:
    DROP_SYMBOL DATABASE_SYMBOL ifExists? schemaRef
;

dropEvent:
    DROP_SYMBOL EVENT_SYMBOL ifExists? eventRef
;

dropFunction:
    DROP_SYMBOL FUNCTION_SYMBOL ifExists? functionRef // Including UDFs.
;

dropProcedure:
    DROP_SYMBOL PROCEDURE_SYMBOL ifExists? procedureRef
;

dropIndex:
    DROP_SYMBOL onlineOption? type = INDEX_SYMBOL indexRef ON_SYMBOL tableRef indexLockAndAlgorithm?
;

dropLogfileGroup:
    DROP_SYMBOL LOGFILE_SYMBOL GROUP_SYMBOL logfileGroupRef (
        dropLogfileGroupOption (COMMA_SYMBOL? dropLogfileGroupOption)*
    )?
;

dropLogfileGroupOption:
    (WAIT_SYMBOL | NO_WAIT_SYMBOL)
    | STORAGE_SYMBOL? ENGINE_SYMBOL EQUAL_OPERATOR? engineRef
;

dropServer:
    DROP_SYMBOL SERVER_SYMBOL ifExists? serverRef
;

dropTable:
    DROP_SYMBOL TEMPORARY_SYMBOL? type = (TABLE_SYMBOL | TABLES_SYMBOL) ifExists? tableRefList (
        RESTRICT_SYMBOL
        | CASCADE_SYMBOL
    )?
;

dropTableSpace:
    DROP_SYMBOL TABLESPACE_SYMBOL tablespaceRef (
        dropLogfileGroupOption (COMMA_SYMBOL? dropLogfileGroupOption)*
    )?
;

dropTrigger:
    DROP_SYMBOL TRIGGER_SYMBOL ifExists? triggerRef
;

dropView:
    DROP_SYMBOL VIEW_SYMBOL ifExists? viewRefList (RESTRICT_SYMBOL | CASCADE_SYMBOL)?
;

dropRole:
    DROP_SYMBOL ROLE_SYMBOL ifExists? roleList
;

dropSpatialReference:
    DROP_SYMBOL SPATIAL_SYMBOL REFERENCE_SYMBOL SYSTEM_SYMBOL ifExists? real_ulonglong_number
;

//--------------------------------------------------------------------------------------------------

renameTableStatement:
    RENAME_SYMBOL (TABLE_SYMBOL | TABLES_SYMBOL) renamePair (COMMA_SYMBOL renamePair)*
;

renamePair:
    tableRef TO_SYMBOL tableName
;

//--------------------------------------------------------------------------------------------------

truncateTableStatement:
    TRUNCATE_SYMBOL TABLE_SYMBOL? tableRef
;

//--------------------------------------------------------------------------------------------------

importStatement:
    IMPORT_SYMBOL TABLE_SYMBOL FROM_SYMBOL textStringLiteralList
;

//--------------- DML statements -------------------------------------------------------------------

callStatement:
    CALL_SYMBOL procedureRef (OPEN_PAR_SYMBOL exprList? CLOSE_PAR_SYMBOL)?
;

deleteStatement:
    ({serverVersion >= 80000}? withClause)? DELETE_SYMBOL deleteStatementOption* (
        FROM_SYMBOL (
            tableAliasRefList USING_SYMBOL tableReferenceList whereClause?           // Multi table variant 1.
            | tableRef partitionDelete? whereClause? orderClause? simpleLimitClause? // Single table delete.
        )
        | tableAliasRefList FROM_SYMBOL tableReferenceList whereClause? // Multi table variant 2.
    )
;

partitionDelete:
    {serverVersion >= 50602}? PARTITION_SYMBOL OPEN_PAR_SYMBOL identifierList CLOSE_PAR_SYMBOL
;

deleteStatementOption: // opt_delete_option in sql_yacc.yy, but the name collides with another rule (delete_options).
    QUICK_SYMBOL
    | LOW_PRIORITY_SYMBOL
    | QUICK_SYMBOL
    | IGNORE_SYMBOL
;

doStatement:
    DO_SYMBOL (
        {serverVersion < 50709}? exprList
        | {serverVersion >= 50709}? selectItemList
    )
;

handlerStatement:
    HANDLER_SYMBOL (
        tableRef OPEN_SYMBOL tableAlias?
        | identifier (
            CLOSE_SYMBOL
            | READ_SYMBOL handlerReadOrScan whereClause? limitClause?
        )
    )
;

handlerReadOrScan:
    (FIRST_SYMBOL | NEXT_SYMBOL) // Scan function.
    | identifier (
        // The rkey part.
        (FIRST_SYMBOL | NEXT_SYMBOL | PREV_SYMBOL | LAST_SYMBOL)
        | (
            EQUAL_OPERATOR
            | LESS_THAN_OPERATOR
            | GREATER_THAN_OPERATOR
            | LESS_OR_EQUAL_OPERATOR
            | GREATER_OR_EQUAL_OPERATOR
        ) OPEN_PAR_SYMBOL values CLOSE_PAR_SYMBOL
    )
;

//--------------------------------------------------------------------------------------------------

insertStatement:
    INSERT_SYMBOL insertLockOption? IGNORE_SYMBOL? INTO_SYMBOL? tableRef usePartition? (
        insertFromConstructor
        | SET_SYMBOL updateList
        | insertQueryExpression
    ) insertUpdateList?
;

insertLockOption:
    LOW_PRIORITY_SYMBOL
    | DELAYED_SYMBOL // Only allowed if no select is used. Check in the semantic phase.
    | HIGH_PRIORITY_SYMBOL
;

insertFromConstructor: (OPEN_PAR_SYMBOL fields? CLOSE_PAR_SYMBOL)? insertValues
;

fields:
    insertIdentifier (COMMA_SYMBOL insertIdentifier)*
;

insertValues: (VALUES_SYMBOL | VALUE_SYMBOL) valueList
;

insertQueryExpression:
    queryExpressionOrParens
    | OPEN_PAR_SYMBOL fields? CLOSE_PAR_SYMBOL queryExpressionOrParens
;

valueList:
    OPEN_PAR_SYMBOL values? CLOSE_PAR_SYMBOL (
        COMMA_SYMBOL OPEN_PAR_SYMBOL values? CLOSE_PAR_SYMBOL
    )*
;

values: (expr | DEFAULT_SYMBOL) (COMMA_SYMBOL (expr | DEFAULT_SYMBOL))*
;

insertUpdateList:
    ON_SYMBOL DUPLICATE_SYMBOL KEY_SYMBOL UPDATE_SYMBOL updateList
;

//--------------------------------------------------------------------------------------------------

loadStatement:
    LOAD_SYMBOL dataOrXml (LOW_PRIORITY_SYMBOL | CONCURRENT_SYMBOL)? LOCAL_SYMBOL? INFILE_SYMBOL textLiteral (
        REPLACE_SYMBOL
        | IGNORE_SYMBOL
    )? INTO_SYMBOL TABLE_SYMBOL tableRef usePartition? charsetClause? xmlRowsIdentifiedBy? fieldsClause? linesClause?
        loadDataFileTail
;

dataOrXml:
    DATA_SYMBOL
    | {serverVersion >= 50500}? XML_SYMBOL
;

xmlRowsIdentifiedBy:
    {serverVersion >= 50500}? ROWS_SYMBOL IDENTIFIED_SYMBOL BY_SYMBOL textString
;

loadDataFileTail:
    (IGNORE_SYMBOL INT_NUMBER (LINES_SYMBOL | ROWS_SYMBOL))? loadDataFileTargetList? (
        SET_SYMBOL updateList
    )?
;

loadDataFileTargetList:
    OPEN_PAR_SYMBOL fieldOrVariableList? CLOSE_PAR_SYMBOL
;

fieldOrVariableList: (columnRef | userVariable) (
        COMMA_SYMBOL (columnRef | userVariable)
    )*
;

//--------------------------------------------------------------------------------------------------

replaceStatement:
    REPLACE_SYMBOL (LOW_PRIORITY_SYMBOL | DELAYED_SYMBOL)? INTO_SYMBOL? tableRef usePartition? (
        insertFromConstructor
        | SET_SYMBOL updateList
        | insertQueryExpression
    )
;

//--------------------------------------------------------------------------------------------------

selectStatement:
    queryExpression
    | queryExpressionParens
    | selectStatementWithInto
;

/*
  From the server grammar:

  MySQL has a syntax extension that allows into clauses in any one of two
  places. They may appear either before the from clause or at the end. All in
  a top-level select statement. This extends the standard syntax in two
  ways. First, we don't have the restriction that the result can contain only
  one row: the into clause might be INTO OUTFILE/DUMPFILE in which case any
  number of rows is allowed. Hence MySQL does not have any special case for
  the standard's <select statement: single row>. Secondly, and this has more
  severe implications for the parser, it makes the grammar ambiguous, because
  in a from-clause-less select statement with an into clause, it is not clear
  whether the into clause is the leading or the trailing one.

  While it's possible to write an unambiguous grammar, it would force us to
  duplicate the entire <select statement> syntax all the way down to the <into
  clause>. So instead we solve it by writing an ambiguous grammar and use
  precedence rules to sort out the shift/reduce conflict.

  The problem is when the parser has seen SELECT <select list>, and sees an
  INTO token. It can now either shift it or reduce what it has to a table-less
  query expression. If it shifts the token, it will accept seeing a FROM token
  next and hence the INTO will be interpreted as the leading INTO. If it
  reduces what it has seen to a table-less select, however, it will interpret
  INTO as the trailing into. But what if the next token is FROM? Obviously,
  we want to always shift INTO. We do this by two precedence declarations: We
  make the INTO token right-associative, and we give it higher precedence than
  an empty from clause, using the artificial token EMPTY_FROM_CLAUSE.

  The remaining problem is that now we allow the leading INTO anywhere, when
  it should be allowed on the top level only. We solve this by manually
  throwing parse errors whenever we reduce a nested query expression if it
  contains an into clause.
*/
selectStatementWithInto:
    OPEN_PAR_SYMBOL selectStatementWithInto CLOSE_PAR_SYMBOL
    | queryExpression intoClause
;

queryExpression:
    ({serverVersion >= 80000}? withClause)? (
        queryExpressionBody orderClause? limitClause?
        | queryExpressionParens (orderClause limitClause? | limitClause)
    ) ({serverVersion < 80000}? procedureAnalyseClause)? lockingClause?
    | {serverVersion >= 80000}? withClause queryExpressionParens lockingClause?
;

queryExpressionBody:
    querySpecification
    | queryExpressionBody UNION_SYMBOL unionOption? (
        querySpecification
        | queryExpressionParens
    )
    | queryExpressionParens UNION_SYMBOL unionOption? (
        querySpecification
        | queryExpressionParens
    )
;

queryExpressionParens:
    OPEN_PAR_SYMBOL (queryExpressionParens | queryExpression) CLOSE_PAR_SYMBOL
;

querySpecification:
    SELECT_SYMBOL selectOption* selectItemList intoClause? fromClause? whereClause? groupByClause? havingClause? (
        {serverVersion >= 80000}? windowClause
    )?
;

subquery:
    queryExpressionParens
;

querySpecOption:
    ALL_SYMBOL
    | DISTINCT_SYMBOL
    | STRAIGHT_JOIN_SYMBOL
    | HIGH_PRIORITY_SYMBOL
    | SQL_SMALL_RESULT_SYMBOL
    | SQL_BIG_RESULT_SYMBOL
    | SQL_BUFFER_RESULT_SYMBOL
    | SQL_CALC_FOUND_ROWS_SYMBOL
;

limitClause:
    LIMIT_SYMBOL limitOptions
;

simpleLimitClause:
    LIMIT_SYMBOL limitOption
;

limitOptions:
    limitOption ((COMMA_SYMBOL | OFFSET_SYMBOL) limitOption)?
;

limitOption:
    identifier
    | (PARAM_MARKER | ULONGLONG_NUMBER | LONG_NUMBER | INT_NUMBER)
;

intoClause:
    INTO_SYMBOL (
        OUTFILE_SYMBOL textStringLiteral charsetClause? fieldsClause? linesClause?
        | DUMPFILE_SYMBOL textStringLiteral
        | (textOrIdentifier | userVariable) (
            COMMA_SYMBOL (textOrIdentifier | userVariable)
        )*
    )
;

procedureAnalyseClause:
    PROCEDURE_SYMBOL ANALYSE_SYMBOL OPEN_PAR_SYMBOL (
        INT_NUMBER (COMMA_SYMBOL INT_NUMBER)?
    )? CLOSE_PAR_SYMBOL
;

havingClause:
    HAVING_SYMBOL expr
;

windowClause:
    WINDOW_SYMBOL windowDefinition (COMMA_SYMBOL windowDefinition)*
;

windowDefinition:
    windowName AS_SYMBOL windowSpec
;

windowSpec:
    OPEN_PAR_SYMBOL windowSpecDetails CLOSE_PAR_SYMBOL
;

windowSpecDetails:
    windowName? (PARTITION_SYMBOL BY_SYMBOL orderOrGroupList)? orderClause? windowFrameClause?
;

windowFrameClause:
    windowFrameUnits windowFrameExtent windowFrameExclusion?
;

windowFrameUnits:
    ROWS_SYMBOL
    | RANGE_SYMBOL
    | GROUPS_SYMBOL
;

windowFrameExtent:
    windowFrameStart
    | windowFrameBetween
;

windowFrameStart:
    UNBOUNDED_SYMBOL PRECEDING_SYMBOL
    | ulonglong_number PRECEDING_SYMBOL
    | PARAM_MARKER PRECEDING_SYMBOL
    | INTERVAL_SYMBOL expr interval PRECEDING_SYMBOL
    | CURRENT_SYMBOL ROW_SYMBOL
;

windowFrameBetween:
    BETWEEN_SYMBOL windowFrameBound AND_SYMBOL windowFrameBound
;

windowFrameBound:
    windowFrameStart
    | UNBOUNDED_SYMBOL FOLLOWING_SYMBOL
    | ulonglong_number FOLLOWING_SYMBOL
    | PARAM_MARKER FOLLOWING_SYMBOL
    | INTERVAL_SYMBOL expr interval FOLLOWING_SYMBOL
;

windowFrameExclusion:
    EXCLUDE_SYMBOL (
        CURRENT_SYMBOL ROW_SYMBOL
        | GROUP_SYMBOL
        | TIES_SYMBOL
        | NO_SYMBOL OTHERS_SYMBOL
    )
;

withClause:
    WITH_SYMBOL RECURSIVE_SYMBOL? commonTableExpression (
        COMMA_SYMBOL commonTableExpression
    )*
;

commonTableExpression:
    identifier columnInternalRefList? AS_SYMBOL subquery
;

groupByClause:
    GROUP_SYMBOL BY_SYMBOL orderOrGroupList olapOption?
;

olapOption:
    WITH_SYMBOL ROLLUP_SYMBOL
    | {serverVersion < 80000}? WITH_SYMBOL CUBE_SYMBOL
;

orderClause:
    ORDER_SYMBOL BY_SYMBOL orderOrGroupList
;

direction:
    ASC_SYMBOL
    | DESC_SYMBOL
;

fromClause:
    FROM_SYMBOL (DUAL_SYMBOL | tableReferenceList)
;

tableReferenceList:
    tableReference (COMMA_SYMBOL tableReference)*
;

selectOption:
    querySpecOption
    | SQL_NO_CACHE_SYMBOL // Deprecated and ignored in 8.0.
    | {serverVersion < 80000}? SQL_CACHE_SYMBOL
    | {serverVersion >= 50704 && serverVersion < 50708}? MAX_STATEMENT_TIME_SYMBOL EQUAL_OPERATOR real_ulong_number
;

lockingClause:
    FOR_SYMBOL lockStrengh ({serverVersion >= 80000}? OF_SYMBOL tableAliasRefList)? (
        {serverVersion >= 80000}? lockedRowAction
    )?
    | LOCK_SYMBOL IN_SYMBOL SHARE_SYMBOL MODE_SYMBOL
;

lockStrengh:
    UPDATE_SYMBOL
    | {serverVersion >= 80000}? SHARE_SYMBOL
;

lockedRowAction:
    SKIP_SYMBOL LOCKED_SYMBOL
    | NOWAIT_SYMBOL
;

selectItemList: (selectItem | MULT_OPERATOR) (COMMA_SYMBOL selectItem)*
;

selectItem:
    tableWild
    | expr selectAlias?
;

selectAlias:
    AS_SYMBOL? (identifier | textStringLiteral)
;

whereClause:
    WHERE_SYMBOL expr
;

tableReference: ( // Note: we have also a tableRef rule for identifiers that reference a table anywhere.
        tableFactor
        | OPEN_CURLY_SYMBOL identifier escapedTableReference CLOSE_CURLY_SYMBOL // ODBC syntax
    ) joinedTable*
;

escapedTableReference:
    tableFactor joinedTable*
;

joinedTable: // Same as joined_table in sql_yacc.yy, but with removed left recursion.
    innerJoinType tableReference (
        ON_SYMBOL expr
        | USING_SYMBOL identifierListWithParentheses
    )?
    | outerJoinType tableReference (
        ON_SYMBOL expr
        | USING_SYMBOL identifierListWithParentheses
    )
    | naturalJoinType tableFactor
;

naturalJoinType:
    NATURAL_SYMBOL INNER_SYMBOL? JOIN_SYMBOL
    | NATURAL_SYMBOL (LEFT_SYMBOL | RIGHT_SYMBOL) OUTER_SYMBOL? JOIN_SYMBOL
;

innerJoinType:
    type = (INNER_SYMBOL | CROSS_SYMBOL)? JOIN_SYMBOL
    | type = STRAIGHT_JOIN_SYMBOL
;

outerJoinType:
    type = (LEFT_SYMBOL | RIGHT_SYMBOL) OUTER_SYMBOL? JOIN_SYMBOL
;

/**
  MySQL has a syntax extension where a comma-separated list of table
  references is allowed as a table reference in itself, for instance

    SELECT * FROM (t1, t2) JOIN t3 ON 1

  which is not allowed in standard SQL. The syntax is equivalent to

    SELECT * FROM (t1 CROSS JOIN t2) JOIN t3 ON 1

  We call this rule tableReferenceListParens.
*/
tableFactor:
    singleTable
    | singleTableParens
    | derivedTable
    | tableReferenceListParens
    | {serverVersion >= 80004}? tableFunction
;

singleTable:
    tableRef usePartition? tableAlias? indexHintList?
;

singleTableParens:
    OPEN_PAR_SYMBOL (singleTable | singleTableParens) CLOSE_PAR_SYMBOL
;

derivedTable:
    subquery tableAlias? ({serverVersion >= 80000}? columnInternalRefList)?
;

// This rule covers both: joined_table_parens and table_reference_list_parens from sql_yacc.yy.
// We can simplify that because we have unrolled the indirect left recursion in joined_table <-> table_reference.
tableReferenceListParens:
    OPEN_PAR_SYMBOL (tableReferenceList | tableReferenceListParens) CLOSE_PAR_SYMBOL
;

tableFunction:
    JSON_TABLE_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL textStringLiteral columnsClause CLOSE_PAR_SYMBOL tableAlias?
;

columnsClause:
    COLUMNS_SYMBOL OPEN_PAR_SYMBOL jtColumn (COMMA_SYMBOL jtColumn)* CLOSE_PAR_SYMBOL
;

jtColumn:
    identifier FOR_SYMBOL ORDINALITY_SYMBOL
    | identifier dataType EXISTS_SYMBOL? PATH_SYMBOL textStringLiteral onEmptyOrError?
    | NESTED_SYMBOL PATH_SYMBOL textStringLiteral columnsClause
;

onEmptyOrError:
    onEmpty onError?
    | onError onEmpty?
;

onEmpty:
    jtOnResponse ON_SYMBOL EMPTY_SYMBOL
;

onError:
    jtOnResponse ON_SYMBOL ERROR_SYMBOL
;

jtOnResponse:
    ERROR_SYMBOL
    | NULL_SYMBOL
    | DEFAULT_SYMBOL textStringLiteral
;

unionOption:
    DISTINCT_SYMBOL
    | ALL_SYMBOL
;

tableAlias: (AS_SYMBOL | EQUAL_OPERATOR)? identifier
;

indexHintList:
    indexHint (COMMA_SYMBOL indexHint)*
;

indexHint:
    indexHintType keyOrIndex indexHintClause? OPEN_PAR_SYMBOL indexList CLOSE_PAR_SYMBOL
    | USE_SYMBOL keyOrIndex indexHintClause? OPEN_PAR_SYMBOL indexList? CLOSE_PAR_SYMBOL
;

indexHintType:
    FORCE_SYMBOL
    | IGNORE_SYMBOL
;

keyOrIndex:
    KEY_SYMBOL
    | INDEX_SYMBOL
;

indexHintClause:
    FOR_SYMBOL (JOIN_SYMBOL | ORDER_SYMBOL BY_SYMBOL | GROUP_SYMBOL BY_SYMBOL)
;

indexList:
    indexListElement (COMMA_SYMBOL indexListElement)*
;

indexListElement:
    identifier
    | PRIMARY_SYMBOL
;

//--------------------------------------------------------------------------------------------------

updateStatement:
    ({serverVersion >= 80000}? withClause)? UPDATE_SYMBOL LOW_PRIORITY_SYMBOL? IGNORE_SYMBOL? tableReferenceList SET_SYMBOL
        updateList whereClause? orderClause? simpleLimitClause?
;

//--------------------------------------------------------------------------------------------------

transactionOrLockingStatement:
    transactionStatement
    | savepointStatement
    | lockStatement
    | xaStatement
;

transactionStatement:
    START_SYMBOL TRANSACTION_SYMBOL transactionCharacteristic*
    | COMMIT_SYMBOL WORK_SYMBOL? (AND_SYMBOL NO_SYMBOL? CHAIN_SYMBOL)? (
        NO_SYMBOL? RELEASE_SYMBOL
    )?
    // SET TRANSACTION is part of setStatement.
;

// BEGIN WORK is separated from transactional statements as it must not appear as part of a stored program.
beginWork:
    BEGIN_SYMBOL WORK_SYMBOL?
;

transactionCharacteristic:
    WITH_SYMBOL CONSISTENT_SYMBOL SNAPSHOT_SYMBOL
    | {serverVersion >= 50605}? READ_SYMBOL (WRITE_SYMBOL | ONLY_SYMBOL)
;

setTransactionCharacteristic:
    ISOLATION_SYMBOL LEVEL_SYMBOL isolationLevel
    | {serverVersion >= 50605}? READ_SYMBOL (WRITE_SYMBOL | ONLY_SYMBOL)
;

isolationLevel:
    REPEATABLE_SYMBOL READ_SYMBOL
    | READ_SYMBOL (COMMITTED_SYMBOL | UNCOMMITTED_SYMBOL)
    | SERIALIZABLE_SYMBOL
;

savepointStatement:
    SAVEPOINT_SYMBOL identifier
    | ROLLBACK_SYMBOL WORK_SYMBOL? (
        TO_SYMBOL SAVEPOINT_SYMBOL? identifier
        | (AND_SYMBOL NO_SYMBOL? CHAIN_SYMBOL)? (NO_SYMBOL? RELEASE_SYMBOL)?
    )
    | RELEASE_SYMBOL SAVEPOINT_SYMBOL identifier
;

lockStatement:
    LOCK_SYMBOL (TABLES_SYMBOL | TABLE_SYMBOL) lockItem (COMMA_SYMBOL lockItem)*
    | {serverVersion >= 80000}? LOCK_SYMBOL INSTANCE_SYMBOL FOR_SYMBOL BACKUP_SYMBOL
    | UNLOCK_SYMBOL (
        TABLES_SYMBOL
        | TABLE_SYMBOL
        | {serverVersion >= 80000}? INSTANCE_SYMBOL
    )
;

lockItem:
    tableRef tableAlias? lockOption
;

lockOption:
    READ_SYMBOL LOCAL_SYMBOL?
    | LOW_PRIORITY_SYMBOL? WRITE_SYMBOL // low priority deprecated since 5.7
;

xaStatement:
    XA_SYMBOL (
        (START_SYMBOL | BEGIN_SYMBOL) xid (JOIN_SYMBOL | RESUME_SYMBOL)?
        | END_SYMBOL xid (SUSPEND_SYMBOL (FOR_SYMBOL MIGRATE_SYMBOL)?)?
        | PREPARE_SYMBOL xid
        | COMMIT_SYMBOL xid (ONE_SYMBOL PHASE_SYMBOL)?
        | ROLLBACK_SYMBOL xid
        | RECOVER_SYMBOL xaConvert
    )
;

xaConvert:
    {serverVersion >= 50704}? (CONVERT_SYMBOL XID_SYMBOL)?
    | /* empty */
;

xid:
    textString (COMMA_SYMBOL textString (COMMA_SYMBOL ulong_number)?)?
;

//--------------------------------------------------------------------------------------------------

replicationStatement:
    PURGE_SYMBOL (BINARY_SYMBOL | MASTER_SYMBOL) LOGS_SYMBOL (
        TO_SYMBOL textLiteral
        | BEFORE_SYMBOL expr
    )
    | changeMaster
    | RESET_SYMBOL resetOption (COMMA_SYMBOL resetOption)*
    | {serverVersion > 80000}? RESET_SYMBOL PERSIST_SYMBOL (ifExists identifier)?
    | slave
    | {serverVersion >= 50700}? changeReplication
    | {serverVersion < 50500}? replicationLoad
    | {serverVersion > 50706}? groupReplication
;

resetOption:
    option = MASTER_SYMBOL masterResetOptions?
    | {serverVersion < 80000}? option = QUERY_SYMBOL CACHE_SYMBOL
    | option = SLAVE_SYMBOL ALL_SYMBOL? channel?
;

masterResetOptions:
    {serverVersion >= 80000}? TO_SYMBOL real_ulong_number
;

replicationLoad:
    LOAD_SYMBOL (DATA_SYMBOL | TABLE_SYMBOL tableRef) FROM_SYMBOL MASTER_SYMBOL
;

changeMaster:
    CHANGE_SYMBOL MASTER_SYMBOL TO_SYMBOL changeMasterOptions channel?
;

changeMasterOptions:
    masterOption (COMMA_SYMBOL masterOption)*
;

masterOption:
    MASTER_HOST_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_BIND_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_USER_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_PASSWORD_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_PORT_SYMBOL EQUAL_OPERATOR ulong_number
    | MASTER_CONNECT_RETRY_SYMBOL EQUAL_OPERATOR ulong_number
    | MASTER_RETRY_COUNT_SYMBOL EQUAL_OPERATOR ulong_number
    | MASTER_DELAY_SYMBOL EQUAL_OPERATOR ulong_number
    | MASTER_SSL_SYMBOL EQUAL_OPERATOR ulong_number
    | MASTER_SSL_CA_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_TLS_VERSION_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_SSL_CAPATH_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_SSL_CERT_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_SSL_CIPHER_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_SSL_KEY_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_SSL_VERIFY_SERVER_CERT_SYMBOL EQUAL_OPERATOR ulong_number
    | MASTER_SSL_CRL_SYMBOL EQUAL_OPERATOR textLiteral
    | MASTER_SSL_CRLPATH_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_PUBLIC_KEY_PATH_SYMBOL EQUAL_OPERATOR textStringNoLinebreak // Conditionally set in the lexer.
    | GET_MASTER_PUBLIC_KEY_SYM EQUAL_OPERATOR ulong_number              // Conditionally set in the lexer.
    | MASTER_HEARTBEAT_PERIOD_SYMBOL EQUAL_OPERATOR ulong_number
    | IGNORE_SERVER_IDS_SYMBOL EQUAL_OPERATOR serverIdList
    | MASTER_AUTO_POSITION_SYMBOL EQUAL_OPERATOR ulong_number
    | masterFileDef
;

masterFileDef:
    MASTER_LOG_FILE_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | MASTER_LOG_POS_SYMBOL EQUAL_OPERATOR ulonglong_number
    | RELAY_LOG_FILE_SYMBOL EQUAL_OPERATOR textStringNoLinebreak
    | RELAY_LOG_POS_SYMBOL EQUAL_OPERATOR ulong_number
;

serverIdList:
    OPEN_PAR_SYMBOL (ulong_number (COMMA_SYMBOL ulong_number)*)? CLOSE_PAR_SYMBOL
;

changeReplication:
    CHANGE_SYMBOL REPLICATION_SYMBOL FILTER_SYMBOL filterDefinition (
        COMMA_SYMBOL filterDefinition
    )* ({serverVersion >= 80000}? channel)?
;

filterDefinition:
    REPLICATE_DO_DB_SYMBOL EQUAL_OPERATOR OPEN_PAR_SYMBOL filterDbList? CLOSE_PAR_SYMBOL
    | REPLICATE_IGNORE_DB_SYMBOL EQUAL_OPERATOR OPEN_PAR_SYMBOL filterDbList? CLOSE_PAR_SYMBOL
    | REPLICATE_DO_TABLE_SYMBOL EQUAL_OPERATOR OPEN_PAR_SYMBOL filterTableList? CLOSE_PAR_SYMBOL
    | REPLICATE_IGNORE_TABLE_SYMBOL EQUAL_OPERATOR OPEN_PAR_SYMBOL filterTableList? CLOSE_PAR_SYMBOL
    | REPLICATE_WILD_DO_TABLE_SYMBOL EQUAL_OPERATOR OPEN_PAR_SYMBOL filterStringList? CLOSE_PAR_SYMBOL
    | REPLICATE_WILD_IGNORE_TABLE_SYMBOL EQUAL_OPERATOR OPEN_PAR_SYMBOL filterStringList? CLOSE_PAR_SYMBOL
    | REPLICATE_REWRITE_DB_SYMBOL EQUAL_OPERATOR OPEN_PAR_SYMBOL filterDbPairList? CLOSE_PAR_SYMBOL
;

filterDbList:
    schemaRef (COMMA_SYMBOL schemaRef)*
;

filterTableList:
    filterTableRef (COMMA_SYMBOL filterTableRef)*
;

filterStringList:
    filterWildDbTableString (COMMA_SYMBOL filterWildDbTableString)*
;

filterWildDbTableString:
    textStringNoLinebreak // sql_yacc.yy checks for the existance of at least one dot char in the string.
;

filterDbPairList:
    schemaIdentifierPair (COMMA_SYMBOL schemaIdentifierPair)*
;

slave:
    START_SYMBOL SLAVE_SYMBOL slaveThreadOptions? (UNTIL_SYMBOL slaveUntilOptions)? slaveConnectionOptions channel?
    | STOP_SYMBOL SLAVE_SYMBOL slaveThreadOptions? channel?
;

slaveUntilOptions:
    (
        masterFileDef
        | {serverVersion >= 50606}? (
            SQL_BEFORE_GTIDS_SYMBOL
            | SQL_AFTER_GTIDS_SYMBOL
        ) EQUAL_OPERATOR textString
        | {serverVersion >= 50606}? SQL_AFTER_MTS_GAPS_SYMBOL
    ) (COMMA_SYMBOL masterFileDef)*
;

slaveConnectionOptions:
    {serverVersion >= 50604}? (USER_SYMBOL EQUAL_OPERATOR textString)? (
        PASSWORD_SYMBOL EQUAL_OPERATOR textString
    )? (DEFAULT_AUTH_SYMBOL EQUAL_OPERATOR textString)? (
        PLUGIN_DIR_SYMBOL EQUAL_OPERATOR textString
    )?
    | /* empty */
;

slaveThreadOptions:
    slaveThreadOption (COMMA_SYMBOL slaveThreadOption)*
;

slaveThreadOption:
    RELAY_THREAD_SYMBOL
    | SQL_THREAD_SYMBOL
;

groupReplication: (START_SYMBOL | STOP_SYMBOL) GROUP_REPLICATION_SYMBOL
;

//--------------------------------------------------------------------------------------------------

preparedStatement:
    type = PREPARE_SYMBOL identifier FROM_SYMBOL (textLiteral | userVariable)
    | executeStatement
    | type = (DEALLOCATE_SYMBOL | DROP_SYMBOL) PREPARE_SYMBOL identifier
;

executeStatement:
    EXECUTE_SYMBOL identifier (USING_SYMBOL executeVarList)?
;

executeVarList:
    userVariable (COMMA_SYMBOL userVariable)*
;

//--------------------------------------------------------------------------------------------------

cloneStatement:
    CLONE_SYMBOL (
        LOCAL_SYMBOL DATA_SYMBOL DIRECTORY_SYMBOL equal? textStringLiteral
        | REMOTE_SYMBOL (FOR_SYMBOL REPLICATION_SYMBOL)?
    )
;

//--------------------------------------------------------------------------------------------------

accountManagementStatement:
    {serverVersion >= 50606}? alterUser
    | createUser
    | dropUser
    | grant
    | renameUser
    | revoke
    | setPassword
    | {serverVersion >= 80000}? setRole
;

alterUser:
    ALTER_SYMBOL USER_SYMBOL ({serverVersion >= 50706}? ifExists)? alterUserTail
;

alterUserTail:
    createOrAlterUserList createUserTail
    | {serverVersion >= 50706}? USER_SYMBOL parentheses IDENTIFIED_SYMBOL BY_SYMBOL textString
    | {serverVersion >= 80000}? user DEFAULT_SYMBOL ROLE_SYMBOL (
        ALL_SYMBOL
        | NONE_SYMBOL
        | roleList
    )
;

createUser:
    CREATE_SYMBOL USER_SYMBOL ({serverVersion >= 50706}? ifNotExists | /* empty */) createOrAlterUserList defaultRoleClause
        createUserTail
;

createUserTail:
    {serverVersion >= 50706}? requireClause? connectOptions? accountLockPasswordExpireOptions?
    | /* empty */
;

defaultRoleClause:
    {serverVersion >= 80000}? (DEFAULT_SYMBOL ROLE_SYMBOL roleList)?
    | /* empty */
;

requireClause:
    REQUIRE_SYMBOL (requireList | option = (SSL_SYMBOL | X509_SYMBOL | NONE_SYMBOL))
;

connectOptions:
    WITH_SYMBOL (
        MAX_QUERIES_PER_HOUR_SYMBOL ulong_number
        | MAX_UPDATES_PER_HOUR_SYMBOL ulong_number
        | MAX_CONNECTIONS_PER_HOUR_SYMBOL ulong_number
        | MAX_USER_CONNECTIONS_SYMBOL ulong_number
    )+
;

accountLockPasswordExpireOptions:
    ACCOUNT_SYMBOL (LOCK_SYMBOL | UNLOCK_SYMBOL)
    | PASSWORD_SYMBOL EXPIRE_SYMBOL (
        INTERVAL_SYMBOL real_ulong_number DAY_SYMBOL
        | (NEVER_SYMBOL | DEFAULT_SYMBOL)
    )?
    | PASSWORD_SYMBOL HISTORY_SYMBOL (real_ulong_number | DEFAULT_SYMBOL)
    | PASSWORD_SYMBOL REUSE_SYMBOL (
        INTERVAL_SYMBOL real_ulong_number DAY_SYMBOL
        | DEFAULT_SYMBOL
    )?
;

dropUser:
    DROP_SYMBOL USER_SYMBOL ({serverVersion >= 50706}? ifExists)? userList
;

grant:
    GRANT_SYMBOL (
        {serverVersion >= 80000}? roleOrPrivilegesList TO_SYMBOL userList (
            WITH_SYMBOL ADMIN_SYMBOL OPTION_SYMBOL
        )?
        | (roleOrPrivilegesList | ALL_SYMBOL PRIVILEGES_SYMBOL?) ON_SYMBOL aclType? grantIdentifier TO_SYMBOL grantTargetList
            versionedRequireClause? grantOptions?
        | {serverVersion >= 50500}? PROXY_SYMBOL ON_SYMBOL user TO_SYMBOL grantTargetList (
            WITH_SYMBOL GRANT_SYMBOL OPTION_SYMBOL
        )?
    )
;

grantTargetList:
    {serverVersion < 80011}? createOrAlterUserList
    | {serverVersion >= 80011}? userList
;

grantOptions:
    {serverVersion < 80011}? WITH_SYMBOL grantOption+
    | {serverVersion >= 80011}? WITH_SYMBOL GRANT_SYMBOL OPTION_SYMBOL
;

versionedRequireClause:
    {serverVersion < 80011}? requireClause
;

renameUser:
    RENAME_SYMBOL USER_SYMBOL user TO_SYMBOL user (COMMA_SYMBOL user TO_SYMBOL user)*
;

revoke:
    REVOKE_SYMBOL (
        {serverVersion >= 80000}? roleOrPrivilegesList FROM_SYMBOL userList
        | roleOrPrivilegesList onTypeTo FROM_SYMBOL userList
        | ALL_SYMBOL PRIVILEGES_SYMBOL? (
            {serverVersion >= 80000}? ON_SYMBOL aclType? grantIdentifier
            | COMMA_SYMBOL GRANT_SYMBOL OPTION_SYMBOL FROM_SYMBOL userList
        )
        | {serverVersion >= 50500}? PROXY_SYMBOL ON_SYMBOL user FROM_SYMBOL userList
    )
;

onTypeTo: // Optional, starting with 8.0.1.
    {serverVersion < 80000}? ON_SYMBOL aclType? grantIdentifier
    | {serverVersion >= 80000}? (ON_SYMBOL aclType? grantIdentifier)?
;

aclType:
    TABLE_SYMBOL
    | FUNCTION_SYMBOL
    | PROCEDURE_SYMBOL
;

setPassword:
    SET_SYMBOL PASSWORD_SYMBOL (FOR_SYMBOL user)? equal (
        PASSWORD_SYMBOL OPEN_PAR_SYMBOL textString CLOSE_PAR_SYMBOL
        | {serverVersion < 50706}? OLD_PASSWORD_SYMBOL OPEN_PAR_SYMBOL textString CLOSE_PAR_SYMBOL
        | textString
    )
;

roleOrPrivilegesList:
    roleOrPrivilege (COMMA_SYMBOL roleOrPrivilege)*
;

roleOrPrivilege:
    {serverVersion > 80000}? (
        roleIdentifierOrText columnInternalRefList?
        | roleIdentifierOrText (AT_TEXT_SUFFIX | AT_SIGN_SYMBOL textOrIdentifier)
    )
    | (SELECT_SYMBOL | INSERT_SYMBOL | UPDATE_SYMBOL | REFERENCES_SYMBOL) columnInternalRefList?
    | (
        DELETE_SYMBOL
        | USAGE_SYMBOL
        | INDEX_SYMBOL
        | DROP_SYMBOL
        | EXECUTE_SYMBOL
        | RELOAD_SYMBOL
        | SHUTDOWN_SYMBOL
        | PROCESS_SYMBOL
        | FILE_SYMBOL
        | PROXY_SYMBOL
        | SUPER_SYMBOL
        | EVENT_SYMBOL
        | TRIGGER_SYMBOL
    )
    | GRANT_SYMBOL OPTION_SYMBOL
    | SHOW_SYMBOL DATABASES_SYMBOL
    | CREATE_SYMBOL (
        TEMPORARY_SYMBOL object = TABLES_SYMBOL
        | object = (ROUTINE_SYMBOL | TABLESPACE_SYMBOL | USER_SYMBOL | VIEW_SYMBOL)
    )?
    | LOCK_SYMBOL TABLES_SYMBOL
    | REPLICATION_SYMBOL object = (CLIENT_SYMBOL | SLAVE_SYMBOL)
    | SHOW_SYMBOL VIEW_SYMBOL
    | ALTER_SYMBOL ROUTINE_SYMBOL?
    | {serverVersion > 80000}? (CREATE_SYMBOL | DROP_SYMBOL) ROLE_SYMBOL
;

grantIdentifier:
    MULT_OPERATOR (DOT_SYMBOL MULT_OPERATOR)?
    | identifier (DOT_SYMBOL MULT_OPERATOR)?
    | tableRef
;

requireList:
    requireListElement (AND_SYMBOL? requireListElement)*
;

requireListElement:
    element = CIPHER_SYMBOL textString
    | element = ISSUER_SYMBOL textString
    | element = SUBJECT_SYMBOL textString
;

grantOption:
    option = GRANT_SYMBOL OPTION_SYMBOL
    | option = MAX_QUERIES_PER_HOUR_SYMBOL ulong_number
    | option = MAX_UPDATES_PER_HOUR_SYMBOL ulong_number
    | option = MAX_CONNECTIONS_PER_HOUR_SYMBOL ulong_number
    | option = MAX_USER_CONNECTIONS_SYMBOL ulong_number
;

setRole:
    SET_SYMBOL ROLE_SYMBOL roleList
    | SET_SYMBOL ROLE_SYMBOL (NONE_SYMBOL | DEFAULT_SYMBOL)
    | SET_SYMBOL DEFAULT_SYMBOL ROLE_SYMBOL (roleList | NONE_SYMBOL | ALL_SYMBOL) TO_SYMBOL roleList
    | SET_SYMBOL ROLE_SYMBOL ALL_SYMBOL (EXCEPT_SYMBOL roleList)?
;

roleList:
    role (COMMA_SYMBOL role)*
;

role:
    roleIdentifierOrText (AT_SIGN_SYMBOL textOrIdentifier)?
;

//--------------------------------------------------------------------------------------------------

tableAdministrationStatement:
    type = ANALYZE_SYMBOL noWriteToBinLog? TABLE_SYMBOL tableRefList
    | type = CHECK_SYMBOL TABLE_SYMBOL tableRefList checkOption*
    | type = CHECKSUM_SYMBOL TABLE_SYMBOL tableRefList (
        QUICK_SYMBOL
        | EXTENDED_SYMBOL
    )?
    | type = OPTIMIZE_SYMBOL noWriteToBinLog? TABLE_SYMBOL tableRefList (
        {serverVersion >= 80000}? histogram
    )?
    | type = REPAIR_SYMBOL noWriteToBinLog? TABLE_SYMBOL tableRefList repairType*
;

histogram:
    UPDATE_SYMBOL HISTOGRAM_SYMBOL ON_SYMBOL identifierList (
        WITH_SYMBOL INT_NUMBER BUCKETS_SYMBOL
    )?
    | DROP_SYMBOL HISTOGRAM_SYMBOL ON_SYMBOL identifierList
;

checkOption:
    FOR_SYMBOL UPGRADE_SYMBOL
    | (QUICK_SYMBOL | FAST_SYMBOL | MEDIUM_SYMBOL | EXTENDED_SYMBOL | CHANGED_SYMBOL)
;

repairType:
    QUICK_SYMBOL
    | EXTENDED_SYMBOL
    | USE_FRM_SYMBOL
;

//--------------------------------------------------------------------------------------------------

installUninstallStatment:
    // COMPONENT_SYMBOL is conditionally set in the lexer.
    action = INSTALL_SYMBOL type = PLUGIN_SYMBOL identifier SONAME_SYMBOL textStringLiteral
    | action = INSTALL_SYMBOL type = COMPONENT_SYMBOL textStringLiteralList
    | action = UNINSTALL_SYMBOL type = PLUGIN_SYMBOL pluginRef
    | action = UNINSTALL_SYMBOL type = COMPONENT_SYMBOL componentRef (
        COMMA_SYMBOL componentRef
    )*
;

//--------------------------------------------------------------------------------------------------

setStatement:
    SET_SYMBOL (
        optionType? TRANSACTION_SYMBOL setTransactionCharacteristic
        // ONE_SHOT is available only until 5.6. Conditionally handled in the lexer.
        | ONE_SHOT_SYMBOL? optionValueNoOptionType (COMMA_SYMBOL optionValueList)?
        | optionType optionValueFollowingOptionType (COMMA_SYMBOL optionValueList)?

        // SET PASSWORD is handled in an own rule.
    )
;

optionValueNoOptionType:
    internalVariableName equal setExprOrDefault
    | charsetClause
    | userVariable equal expr
    | setSystemVariable equal setExprOrDefault
    | NAMES_SYMBOL (
        equal expr
        | charsetName (COLLATE_SYMBOL collationName)?
        | {serverVersion >= 80011}? DEFAULT_SYMBOL
    )
;

setSystemVariable:
    AT_AT_SIGN_SYMBOL setVarIdentType? internalVariableName
;

optionValueFollowingOptionType:
    internalVariableName equal setExprOrDefault
;

setExprOrDefault:
    expr
    | (DEFAULT_SYMBOL | ON_SYMBOL | ALL_SYMBOL | BINARY_SYMBOL)
    | {serverVersion >= 80000}? (ROW_SYMBOL | SYSTEM_SYMBOL)
;

optionValueList:
    optionValue (COMMA_SYMBOL optionValue)*
;

optionValue:
    optionType internalVariableName equal setExprOrDefault
    | optionValueNoOptionType
;

//--------------------------------------------------------------------------------------------------

showStatement:
    SHOW_SYMBOL (
        {serverVersion < 50700}? value = AUTHORS_SYMBOL
        | value = DATABASES_SYMBOL likeOrWhere?
        | showCommandType? value = TABLES_SYMBOL inDb? likeOrWhere?
        | FULL_SYMBOL? value = TRIGGERS_SYMBOL inDb? likeOrWhere?
        | value = EVENTS_SYMBOL inDb? likeOrWhere?
        | value = TABLE_SYMBOL STATUS_SYMBOL inDb? likeOrWhere?
        | value = OPEN_SYMBOL TABLES_SYMBOL inDb? likeOrWhere?
        | {serverVersion >= 50500}? value = PLUGINS_SYMBOL
        | value = ENGINE_SYMBOL (engineRef | ALL_SYMBOL) (
            STATUS_SYMBOL
            | MUTEX_SYMBOL
            | LOGS_SYMBOL
        )
        | showCommandType? value = COLUMNS_SYMBOL (FROM_SYMBOL | IN_SYMBOL) tableRef inDb? likeOrWhere?
        | (BINARY_SYMBOL | MASTER_SYMBOL) value = LOGS_SYMBOL
        | value = SLAVE_SYMBOL (HOSTS_SYMBOL | STATUS_SYMBOL nonBlocking channel?)
        | value = (BINLOG_SYMBOL | RELAYLOG_SYMBOL) EVENTS_SYMBOL (
            IN_SYMBOL textString
        )? (FROM_SYMBOL ulonglong_number)? limitClause? channel?
        | ({serverVersion >= 80000}? EXTENDED_SYMBOL)? value = (
            INDEX_SYMBOL
            | INDEXES_SYMBOL
            | KEYS_SYMBOL
        ) fromOrIn tableRef inDb? whereClause?
        | STORAGE_SYMBOL? value = ENGINES_SYMBOL
        | COUNT_SYMBOL OPEN_PAR_SYMBOL MULT_OPERATOR CLOSE_PAR_SYMBOL value = (
            WARNINGS_SYMBOL
            | ERRORS_SYMBOL
        )
        | value = WARNINGS_SYMBOL limitClause?
        | value = ERRORS_SYMBOL limitClause?
        | value = PROFILES_SYMBOL
        | value = PROFILE_SYMBOL (profileType (COMMA_SYMBOL profileType)*)? (
            FOR_SYMBOL QUERY_SYMBOL INT_NUMBER
        )? limitClause?
        | optionType? value = (STATUS_SYMBOL | VARIABLES_SYMBOL) likeOrWhere?
        | FULL_SYMBOL? value = PROCESSLIST_SYMBOL
        | charset likeOrWhere?
        | value = COLLATION_SYMBOL likeOrWhere?
        | {serverVersion < 50700}? value = CONTRIBUTORS_SYMBOL
        | value = PRIVILEGES_SYMBOL
        | value = GRANTS_SYMBOL (FOR_SYMBOL user)?
        | {serverVersion >= 50500}? value = GRANTS_SYMBOL FOR_SYMBOL user USING_SYMBOL userList
        | value = MASTER_SYMBOL STATUS_SYMBOL
        | value = CREATE_SYMBOL (
            object = DATABASE_SYMBOL ifNotExists? schemaRef
            | object = EVENT_SYMBOL eventRef
            | object = FUNCTION_SYMBOL functionRef
            | object = PROCEDURE_SYMBOL procedureRef
            | object = TABLE_SYMBOL tableRef
            | object = TRIGGER_SYMBOL triggerRef
            | object = VIEW_SYMBOL viewRef
            | {serverVersion >= 50704}? object = USER_SYMBOL user
        )
        | value = PROCEDURE_SYMBOL STATUS_SYMBOL likeOrWhere?
        | value = FUNCTION_SYMBOL STATUS_SYMBOL likeOrWhere?
        | value = PROCEDURE_SYMBOL CODE_SYMBOL procedureRef
        | value = FUNCTION_SYMBOL CODE_SYMBOL functionRef
    )
;

showCommandType:
    FULL_SYMBOL
    | {serverVersion >= 80000}? EXTENDED_SYMBOL FULL_SYMBOL?
;

nonBlocking:
    {serverVersion >= 50700 && serverVersion < 50706}? NONBLOCKING_SYMBOL?
    | /* empty */
;

fromOrIn:
    FROM_SYMBOL
    | IN_SYMBOL
;

inDb:
    fromOrIn identifier
;

profileType:
    BLOCK_SYMBOL IO_SYMBOL
    | CONTEXT_SYMBOL SWITCHES_SYMBOL
    | PAGE_SYMBOL FAULTS_SYMBOL
    | (
        ALL_SYMBOL
        | CPU_SYMBOL
        | IPC_SYMBOL
        | MEMORY_SYMBOL
        | SOURCE_SYMBOL
        | SWAPS_SYMBOL
    )
;

//--------------------------------------------------------------------------------------------------

otherAdministrativeStatement:
    type = BINLOG_SYMBOL textLiteral
    | type = CACHE_SYMBOL INDEX_SYMBOL keyCacheListOrParts IN_SYMBOL (
        identifier
        | DEFAULT_SYMBOL
    )
    | type = FLUSH_SYMBOL noWriteToBinLog? (
        flushTables
        | flushOption (COMMA_SYMBOL flushOption)*
    )
    | type = KILL_SYMBOL (CONNECTION_SYMBOL | QUERY_SYMBOL)? expr
    | type = LOAD_SYMBOL INDEX_SYMBOL INTO_SYMBOL CACHE_SYMBOL preloadTail
    | {serverVersion >= 50709}? type = SHUTDOWN_SYMBOL
;

keyCacheListOrParts:
    keyCacheList
    | assignToKeycachePartition
;

keyCacheList:
    assignToKeycache (COMMA_SYMBOL assignToKeycache)*
;

assignToKeycache:
    tableRef cacheKeyList?
;

assignToKeycachePartition:
    tableRef PARTITION_SYMBOL OPEN_PAR_SYMBOL allOrPartitionNameList CLOSE_PAR_SYMBOL cacheKeyList?
;

cacheKeyList:
    keyOrIndex OPEN_PAR_SYMBOL keyUsageList? CLOSE_PAR_SYMBOL
;

keyUsageElement:
    identifier
    | PRIMARY_SYMBOL
;

keyUsageList:
    keyUsageElement (COMMA_SYMBOL keyUsageElement)*
;

flushOption:
    option = (
        DES_KEY_FILE_SYMBOL // No longer used from 8.0 onwards. Taken out by lexer.
        | HOSTS_SYMBOL
        | PRIVILEGES_SYMBOL
        | STATUS_SYMBOL
        | USER_RESOURCES_SYMBOL
    )
    | logType? option = LOGS_SYMBOL
    | option = RELAY_SYMBOL LOGS_SYMBOL channel?
    | {serverVersion < 80000}? option = QUERY_SYMBOL CACHE_SYMBOL
    | {serverVersion >= 50706}? option = OPTIMIZER_COSTS_SYMBOL
;

logType:
    BINARY_SYMBOL
    | ENGINE_SYMBOL
    | ERROR_SYMBOL
    | GENERAL_SYMBOL
    | SLOW_SYMBOL
;

flushTables:
    (TABLES_SYMBOL | TABLE_SYMBOL) (
        WITH_SYMBOL READ_SYMBOL LOCK_SYMBOL
        | identifierList flushTablesOptions?
    )?
;

flushTablesOptions:
    {serverVersion >= 50606}? FOR_SYMBOL EXPORT_SYMBOL
    | WITH_SYMBOL READ_SYMBOL LOCK_SYMBOL
;

preloadTail:
    tableRef adminPartition cacheKeyList? (IGNORE_SYMBOL LEAVES_SYMBOL)?
    | preloadList
;

preloadList:
    preloadKeys (COMMA_SYMBOL preloadKeys)*
;

preloadKeys:
    tableRef cacheKeyList? (IGNORE_SYMBOL LEAVES_SYMBOL)?
;

adminPartition:
    {serverVersion >= 50500}? (
        PARTITION_SYMBOL OPEN_PAR_SYMBOL allOrPartitionNameList CLOSE_PAR_SYMBOL
    )
;

//--------------------------------------------------------------------------------------------------

resourceGroupManagement:
    createResourceGroup
    | alterResourceGroup
    | setResourceGroup
    | dropResourceGroup
;

createResourceGroup:
    CREATE_SYMBOL RESOURCE_SYMBOL GROUP_SYMBOL identifier TYPE_SYMBOL equal? (
        USER_SYMBOL
        | SYSTEM_SYMBOL
    ) resourceGroupVcpuList? resourceGroupPriority? resourceGroupEnableDisable?
;

resourceGroupVcpuList:
    VCPU_SYMBOL equal? vcpuNumOrRange (COMMA_SYMBOL? vcpuNumOrRange)*
;

vcpuNumOrRange:
    INT_NUMBER (MINUS_OPERATOR INT_NUMBER)?
;

resourceGroupPriority:
    THREAD_PRIORITY_SYMBOL equal? INT_NUMBER
;

resourceGroupEnableDisable:
    ENABLE_SYMBOL
    | DISABLE_SYMBOL
;

alterResourceGroup:
    ALTER_SYMBOL RESOURCE_SYMBOL GROUP_SYMBOL resourceGroupRef resourceGroupVcpuList? resourceGroupPriority?
        resourceGroupEnableDisable? FORCE_SYMBOL?
;

setResourceGroup:
    SET_SYMBOL RESOURCE_SYMBOL GROUP_SYMBOL identifier (FOR_SYMBOL threadIdList)?
;

threadIdList:
    real_ulong_number (COMMA_SYMBOL? real_ulong_number)*
;

dropResourceGroup:
    DROP_SYMBOL RESOURCE_SYMBOL GROUP_SYMBOL resourceGroupRef FORCE_SYMBOL?
;

//--------------------------------------------------------------------------------------------------

utilityStatement:
    describeCommand
    | explainCommand
    | helpCommand
    | useCommand
    | {serverVersion >= 80011}? restartServer
;

describeCommand:
    (DESCRIBE_SYMBOL | DESC_SYMBOL) tableRef (textString | columnRef)?
;

explainCommand:
    (DESCRIBE_SYMBOL | DESC_SYMBOL) (
        // Format must be "traditional" or "json".
        {serverVersion < 80000}? EXTENDED_SYMBOL
        | {serverVersion < 80000}? PARTITIONS_SYMBOL
        | {serverVersion >= 50605}? FORMAT_SYMBOL EQUAL_OPERATOR textOrIdentifier
    )? explainableStatement
;

// Before server version 5.6 only select statements were explainable.
explainableStatement:
    selectStatement
    | {serverVersion >= 50603}? (
        deleteStatement
        | insertStatement
        | replaceStatement
        | updateStatement
    )
    | {serverVersion >= 50700}? FOR_SYMBOL CONNECTION_SYMBOL real_ulong_number
;

helpCommand:
    HELP_SYMBOL textOrIdentifier
;

useCommand:
    USE_SYMBOL identifier
;

restartServer:
    RESTART_SYMBOL
;

//----------------- Expression support -------------------------------------------------------------

expr:
    boolPri (IS_SYMBOL notRule? type = (TRUE_SYMBOL | FALSE_SYMBOL | UNKNOWN_SYMBOL))? # exprIs
    | NOT_SYMBOL expr                                                                  # exprNot
    | expr op = (AND_SYMBOL | LOGICAL_AND_OPERATOR) expr                               # exprAnd
    | expr XOR_SYMBOL expr                                                             # exprXor
    | expr op = (OR_SYMBOL | LOGICAL_OR_OPERATOR) expr                                 # exprOr
;

boolPri:
    predicate                                           # primaryExprPredicate
    | boolPri IS_SYMBOL notRule? NULL_SYMBOL            # primaryExprIsNull
    | boolPri compOp predicate                          # primaryExprCompare
    | boolPri compOp (ALL_SYMBOL | ANY_SYMBOL) subquery # primaryExprAllAny
;

compOp:
    EQUAL_OPERATOR
    | NULL_SAFE_EQUAL_OPERATOR
    | GREATER_OR_EQUAL_OPERATOR
    | GREATER_THAN_OPERATOR
    | LESS_OR_EQUAL_OPERATOR
    | LESS_THAN_OPERATOR
    | NOT_EQUAL_OPERATOR
;

predicate:
    bitExpr (notRule? predicateOperations | SOUNDS_SYMBOL LIKE_SYMBOL bitExpr)?
;

predicateOperations:
    IN_SYMBOL (subquery | OPEN_PAR_SYMBOL exprList CLOSE_PAR_SYMBOL) # predicateExprIn
    | BETWEEN_SYMBOL bitExpr AND_SYMBOL predicate                    # predicateExprBetween
    | LIKE_SYMBOL simpleExpr (ESCAPE_SYMBOL simpleExpr)?             # predicateExprLike
    | REGEXP_SYMBOL bitExpr                                          # predicateExprRegex
;

bitExpr:
    simpleExpr
    | bitExpr op = BITWISE_XOR_OPERATOR bitExpr
    | bitExpr op = (
        MULT_OPERATOR
        | DIV_OPERATOR
        | MOD_OPERATOR
        | DIV_SYMBOL
        | MOD_SYMBOL
    ) bitExpr
    | bitExpr op = (PLUS_OPERATOR | MINUS_OPERATOR) bitExpr
    | bitExpr op = (PLUS_OPERATOR | MINUS_OPERATOR) INTERVAL_SYMBOL expr interval
    | bitExpr op = (SHIFT_LEFT_OPERATOR | SHIFT_RIGHT_OPERATOR) bitExpr
    | bitExpr op = BITWISE_AND_OPERATOR bitExpr
    | bitExpr op = BITWISE_OR_OPERATOR bitExpr
;

simpleExpr:
    variable                                                                                             # simpleExprVariable
    | columnRef jsonOperator?                                                                            # simpleExprColumnRef
    | runtimeFunctionCall                                                                                # simpleExprRuntimeFunction
    | functionCall                                                                                       # simpleExprFunction
    | simpleExpr COLLATE_SYMBOL textOrIdentifier                                                         # simpleExprCollate
    | literal                                                                                            # simpleExprLiteral
    | PARAM_MARKER                                                                                       # simpleExprParamMarker
    | sumExpr                                                                                            # simpleExprSum
    | {serverVersion >= 80000}? groupingOperation                                                        # simpleExprGroupingOperation
    | {serverVersion >= 80000}? windowFunctionCall                                                       # simpleExprWindowingFunction
    | simpleExpr CONCAT_PIPES_SYMBOL simpleExpr                                                          # simpleExprConcat
    | op = (PLUS_OPERATOR | MINUS_OPERATOR | BITWISE_NOT_OPERATOR) simpleExpr                            # simpleExprUnary
    | not2Rule simpleExpr                                                                                # simpleExprNot
    | ROW_SYMBOL? OPEN_PAR_SYMBOL exprList CLOSE_PAR_SYMBOL                                              # simpleExprList
    | EXISTS_SYMBOL? subquery                                                                            # simpleExprSubQuery
    | OPEN_CURLY_SYMBOL identifier expr CLOSE_CURLY_SYMBOL                                               # simpleExprOdbc
    | MATCH_SYMBOL identListArg AGAINST_SYMBOL OPEN_PAR_SYMBOL bitExpr fulltextOptions? CLOSE_PAR_SYMBOL # simpleExprMatch
    | BINARY_SYMBOL simpleExpr                                                                           # simpleExprBinary
    | CAST_SYMBOL OPEN_PAR_SYMBOL expr AS_SYMBOL castType CLOSE_PAR_SYMBOL                               # simpleExprCast
    | CASE_SYMBOL expr? (whenExpression thenExpression)+ elseExpression? END_SYMBOL                      # simpleExprCase
    | CONVERT_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL castType CLOSE_PAR_SYMBOL                         # simpleExprConvert
    | CONVERT_SYMBOL OPEN_PAR_SYMBOL expr USING_SYMBOL charsetName CLOSE_PAR_SYMBOL                      # simpleExprConvertUsing
    | DEFAULT_SYMBOL OPEN_PAR_SYMBOL simpleIdentifier CLOSE_PAR_SYMBOL                                   # simpleExprDefault
    | VALUES_SYMBOL OPEN_PAR_SYMBOL simpleIdentifier CLOSE_PAR_SYMBOL                                    # simpleExprValues
    | INTERVAL_SYMBOL expr interval PLUS_OPERATOR expr                                                   # simpleExprInterval
;

jsonOperator:
    {serverVersion >= 50708}? JSON_SEPARATOR_SYMBOL textStringLiteral
    | {serverVersion >= 50713}? JSON_UNQUOTED_SEPARATOR_SYMBOL textStringLiteral
;

sumExpr:
    name = AVG_SYMBOL OPEN_PAR_SYMBOL DISTINCT_SYMBOL? inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = (BIT_AND_SYMBOL | BIT_OR_SYMBOL | BIT_XOR_SYMBOL) OPEN_PAR_SYMBOL inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | {serverVersion >= 80000}? jsonFunction
    | name = COUNT_SYMBOL OPEN_PAR_SYMBOL ALL_SYMBOL? MULT_OPERATOR CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = COUNT_SYMBOL OPEN_PAR_SYMBOL (
        ALL_SYMBOL? MULT_OPERATOR
        | inSumExpr
        | DISTINCT_SYMBOL exprList
    ) CLOSE_PAR_SYMBOL ({serverVersion >= 80000}? windowingClause)?
    | name = MIN_SYMBOL OPEN_PAR_SYMBOL DISTINCT_SYMBOL? inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = MAX_SYMBOL OPEN_PAR_SYMBOL DISTINCT_SYMBOL? inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = STD_SYMBOL OPEN_PAR_SYMBOL inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = VARIANCE_SYMBOL OPEN_PAR_SYMBOL inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = STDDEV_SAMP_SYMBOL OPEN_PAR_SYMBOL inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = VAR_SAMP_SYMBOL OPEN_PAR_SYMBOL inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = SUM_SYMBOL OPEN_PAR_SYMBOL DISTINCT_SYMBOL? inSumExpr CLOSE_PAR_SYMBOL (
        {serverVersion >= 80000}? windowingClause
    )?
    | name = GROUP_CONCAT_SYMBOL OPEN_PAR_SYMBOL DISTINCT_SYMBOL? exprList orderClause? (
        SEPARATOR_SYMBOL textString
    )? CLOSE_PAR_SYMBOL ({serverVersion >= 80000}? windowingClause)?
;

groupingOperation:
    GROUPING_SYMBOL OPEN_PAR_SYMBOL exprList CLOSE_PAR_SYMBOL
;

windowFunctionCall:
    (
        ROW_NUMBER_SYMBOL
        | RANK_SYMBOL
        | DENSE_RANK_SYMBOL
        | CUME_DIST_SYMBOL
        | PERCENT_RANK_SYMBOL
    ) parentheses windowingClause
    | NTILE_SYMBOL OPEN_PAR_SYMBOL simpleExpr CLOSE_PAR_SYMBOL windowingClause
    | (LEAD_SYMBOL | LAG_SYMBOL) OPEN_PAR_SYMBOL expr leadLagInfo? CLOSE_PAR_SYMBOL nullTreatment? windowingClause
    | (FIRST_VALUE_SYMBOL | LAST_VALUE_SYMBOL) OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL nullTreatment? windowingClause
    | NTH_VALUE_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL simpleExpr CLOSE_PAR_SYMBOL (
        FROM_SYMBOL (FIRST_SYMBOL | LAST_SYMBOL)
    )? nullTreatment? windowingClause
;

windowingClause:
    OVER_SYMBOL (windowName | windowSpec)
;

leadLagInfo:
    COMMA_SYMBOL (ulonglong_number | PARAM_MARKER) (COMMA_SYMBOL expr)?
;

nullTreatment:
    (RESPECT_SYMBOL | IGNORE_SYMBOL) NULLS_SYMBOL
;

jsonFunction:
    JSON_ARRAYAGG_SYMBOL OPEN_PAR_SYMBOL inSumExpr CLOSE_PAR_SYMBOL windowingClause?
    | JSON_OBJECTAGG_SYMBOL OPEN_PAR_SYMBOL inSumExpr COMMA_SYMBOL inSumExpr CLOSE_PAR_SYMBOL windowingClause?
;

inSumExpr:
    ALL_SYMBOL? expr
;

identListArg:
    identList
    | OPEN_PAR_SYMBOL identList CLOSE_PAR_SYMBOL
;

identList:
    simpleIdentifier (COMMA_SYMBOL simpleIdentifier)*
;

fulltextOptions:
    IN_SYMBOL BOOLEAN_SYMBOL MODE_SYMBOL
    | IN_SYMBOL NATURAL_SYMBOL LANGUAGE_SYMBOL MODE_SYMBOL (
        WITH_SYMBOL QUERY_SYMBOL EXPANSION_SYMBOL
    )?
    | WITH_SYMBOL QUERY_SYMBOL EXPANSION_SYMBOL
;

runtimeFunctionCall:
    // Function names that are keywords.
    name = CHAR_SYMBOL OPEN_PAR_SYMBOL exprList (USING_SYMBOL charsetName)? CLOSE_PAR_SYMBOL
    | name = CURRENT_USER_SYMBOL parentheses?
    | name = DATE_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = DAY_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = HOUR_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = INSERT_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr COMMA_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = INTERVAL_SYMBOL OPEN_PAR_SYMBOL expr (COMMA_SYMBOL expr)+ CLOSE_PAR_SYMBOL
    | name = LEFT_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = MINUTE_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = MONTH_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = RIGHT_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = SECOND_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = TIME_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = TIMESTAMP_SYMBOL OPEN_PAR_SYMBOL expr (COMMA_SYMBOL expr)? CLOSE_PAR_SYMBOL
    | trimFunction
    | name = USER_SYMBOL parentheses
    | name = VALUES_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = YEAR_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL

    // Function names that are not keywords.
    | name = (ADDDATE_SYMBOL | SUBDATE_SYMBOL) OPEN_PAR_SYMBOL expr COMMA_SYMBOL (
        expr
        | INTERVAL_SYMBOL expr interval
    ) CLOSE_PAR_SYMBOL
    | name = CURDATE_SYMBOL parentheses?
    | name = CURTIME_SYMBOL timeFunctionParameters?
    | name = (DATE_ADD_SYMBOL | DATE_SUB_SYMBOL) OPEN_PAR_SYMBOL expr COMMA_SYMBOL INTERVAL_SYMBOL expr interval CLOSE_PAR_SYMBOL
    | name = EXTRACT_SYMBOL OPEN_PAR_SYMBOL interval FROM_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = GET_FORMAT_SYMBOL OPEN_PAR_SYMBOL dateTimeTtype COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = NOW_SYMBOL timeFunctionParameters?
    | name = POSITION_SYMBOL OPEN_PAR_SYMBOL bitExpr IN_SYMBOL expr CLOSE_PAR_SYMBOL
    | substringFunction
    | name = SYSDATE_SYMBOL timeFunctionParameters?
    | name = (TIMESTAMP_ADD_SYMBOL | TIMESTAMP_DIFF_SYMBOL) OPEN_PAR_SYMBOL intervalTimeStamp COMMA_SYMBOL expr COMMA_SYMBOL expr
        CLOSE_PAR_SYMBOL
    | name = UTC_DATE_SYMBOL parentheses?
    | name = UTC_TIME_SYMBOL timeFunctionParameters?
    | name = UTC_TIMESTAMP_SYMBOL timeFunctionParameters?

    // Function calls with other conflicts.
    | name = ASCII_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = CHARSET_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = COALESCE_SYMBOL exprListWithParentheses
    | name = COLLATION_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = DATABASE_SYMBOL parentheses
    | name = IF_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = FORMAT_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr (COMMA_SYMBOL expr)? CLOSE_PAR_SYMBOL
    | name = MICROSECOND_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = MOD_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | {serverVersion < 50607}? name = OLD_PASSWORD_SYMBOL OPEN_PAR_SYMBOL textLiteral CLOSE_PAR_SYMBOL
    | {serverVersion < 80011}? name = PASSWORD_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = QUARTER_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = REPEAT_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = REPLACE_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = REVERSE_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = ROW_COUNT_SYMBOL parentheses
    | name = TRUNCATE_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = WEEK_SYMBOL OPEN_PAR_SYMBOL expr (COMMA_SYMBOL expr)? CLOSE_PAR_SYMBOL
    | {serverVersion >= 50600}? name = WEIGHT_STRING_SYMBOL OPEN_PAR_SYMBOL expr (
        (AS_SYMBOL CHAR_SYMBOL wsNumCodepoints)? (
            {serverVersion < 80000}? weightStringLevels
        )?
        | AS_SYMBOL BINARY_SYMBOL wsNumCodepoints
        | COMMA_SYMBOL ulong_number COMMA_SYMBOL ulong_number COMMA_SYMBOL ulong_number
    ) CLOSE_PAR_SYMBOL
    | geometryFunction
;

geometryFunction:
    {serverVersion < 50706}? name = CONTAINS_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = GEOMETRYCOLLECTION_SYMBOL OPEN_PAR_SYMBOL exprList? CLOSE_PAR_SYMBOL
    | name = LINESTRING_SYMBOL exprListWithParentheses
    | name = MULTILINESTRING_SYMBOL exprListWithParentheses
    | name = MULTIPOINT_SYMBOL exprListWithParentheses
    | name = MULTIPOLYGON_SYMBOL exprListWithParentheses
    | name = POINT_SYMBOL OPEN_PAR_SYMBOL expr COMMA_SYMBOL expr CLOSE_PAR_SYMBOL
    | name = POLYGON_SYMBOL exprListWithParentheses
;

timeFunctionParameters:
    OPEN_PAR_SYMBOL fractionalPrecision? CLOSE_PAR_SYMBOL
;

fractionalPrecision:
    {serverVersion >= 50604}? INT_NUMBER
;

weightStringLevels:
    LEVEL_SYMBOL (
        real_ulong_number MINUS_OPERATOR real_ulong_number
        | weightStringLevelListItem (COMMA_SYMBOL weightStringLevelListItem)*
    )
;

weightStringLevelListItem:
    real_ulong_number ((ASC_SYMBOL | DESC_SYMBOL) REVERSE_SYMBOL? | REVERSE_SYMBOL)?
;

dateTimeTtype:
    DATE_SYMBOL
    | TIME_SYMBOL
    | DATETIME_SYMBOL
    | TIMESTAMP_SYMBOL
;

trimFunction:
    TRIM_SYMBOL OPEN_PAR_SYMBOL (
        expr (FROM_SYMBOL expr)?
        | LEADING_SYMBOL expr? FROM_SYMBOL expr
        | TRAILING_SYMBOL expr? FROM_SYMBOL expr
        | BOTH_SYMBOL expr? FROM_SYMBOL expr
    ) CLOSE_PAR_SYMBOL
;

substringFunction:
    SUBSTRING_SYMBOL OPEN_PAR_SYMBOL expr (
        COMMA_SYMBOL expr (COMMA_SYMBOL expr)?
        | FROM_SYMBOL expr (FOR_SYMBOL expr)?
    ) CLOSE_PAR_SYMBOL
;

functionCall:
    pureIdentifier OPEN_PAR_SYMBOL udfExprList? CLOSE_PAR_SYMBOL     // For both UDF + other functions.
    | qualifiedIdentifier OPEN_PAR_SYMBOL exprList? CLOSE_PAR_SYMBOL // Other functions only.
;

udfExprList:
    udfExpr (COMMA_SYMBOL udfExpr)*
;

udfExpr:
    expr selectAlias?
;

variable:
    userVariable (ASSIGN_OPERATOR expr)?
    | systemVariable
;

userVariable: (AT_SIGN_SYMBOL textOrIdentifier)
    | AT_TEXT_SUFFIX
;

systemVariable:
    AT_AT_SIGN_SYMBOL varIdentType? textOrIdentifier dotIdentifier?
;

internalVariableName:
    identifier dotIdentifier? // Check in semantic phase that the first id is not global/local/session/default.
    | DEFAULT_SYMBOL dotIdentifier
;

whenExpression:
    WHEN_SYMBOL expr
;

thenExpression:
    THEN_SYMBOL expr
;

elseExpression:
    ELSE_SYMBOL expr
;

castType:
    BINARY_SYMBOL fieldLength?
    | CHAR_SYMBOL fieldLength? charsetWithOptBinary?
    | nchar fieldLength?
    | SIGNED_SYMBOL INT_SYMBOL?
    | UNSIGNED_SYMBOL INT_SYMBOL?
    | DATE_SYMBOL
    | TIME_SYMBOL typeDatetimePrecision?
    | DATETIME_SYMBOL typeDatetimePrecision?
    | DECIMAL_SYMBOL floatOptions?
    | {serverVersion >= 50708}? JSON_SYMBOL
;

exprList:
    expr (COMMA_SYMBOL expr)*
;

charset:
    CHAR_SYMBOL SET_SYMBOL
    | CHARSET_SYMBOL
;

notRule:
    NOT_SYMBOL
    | NOT2_SYMBOL // A NOT with a different (higher) operator precedence.
;

not2Rule:
    LOGICAL_NOT_OPERATOR
    | NOT2_SYMBOL
;

// None of the microsecond variants can be used in schedules (e.g. events).
interval:
    intervalTimeStamp
    | (
        SECOND_MICROSECOND_SYMBOL
        | MINUTE_MICROSECOND_SYMBOL
        | MINUTE_SECOND_SYMBOL
        | HOUR_MICROSECOND_SYMBOL
        | HOUR_SECOND_SYMBOL
        | HOUR_MINUTE_SYMBOL
        | DAY_MICROSECOND_SYMBOL
        | DAY_SECOND_SYMBOL
        | DAY_MINUTE_SYMBOL
        | DAY_HOUR_SYMBOL
        | YEAR_MONTH_SYMBOL
    )
;

// Support for SQL_TSI_* units is added by mapping those to tokens without SQL_TSI_ prefix.
intervalTimeStamp:
    MICROSECOND_SYMBOL
    | SECOND_SYMBOL
    | MINUTE_SYMBOL
    | HOUR_SYMBOL
    | DAY_SYMBOL
    | WEEK_SYMBOL
    | MONTH_SYMBOL
    | QUARTER_SYMBOL
    | YEAR_SYMBOL
;

exprListWithParentheses:
    OPEN_PAR_SYMBOL exprList CLOSE_PAR_SYMBOL
;

// In the server grammar are 2 different rules with the same content (different actions though).
// We can use a single rule instead.
orderOrGroupList:
    orderExpression (COMMA_SYMBOL orderExpression)*
;

orderExpression:
    expr direction?
;

channel:
    {serverVersion >= 50706}? FOR_SYMBOL CHANNEL_SYMBOL textStringNoLinebreak
;

//----------------- Stored program rules -----------------------------------------------------------

// Compound syntax for stored procedures, stored functions, triggers and events.
// Implements both, sp_proc_stmt and ev_sql_stmt_inner from the server grammar.
compoundStatement:
    simpleStatement
    | returnStatement
    | ifStatement
    | caseStatement
    | labeledBlock
    | unlabeledBlock
    | labeledControl
    | unlabeledControl
    | leaveStatement
    | iterateStatement
    | cursorOpen
    | cursorFetch
    | cursorClose
;

returnStatement:
    RETURN_SYMBOL expr
;

ifStatement:
    IF_SYMBOL ifBody END_SYMBOL IF_SYMBOL
;

ifBody:
    expr thenStatement (ELSEIF_SYMBOL ifBody | ELSE_SYMBOL compoundStatementList)?
;

thenStatement:
    THEN_SYMBOL compoundStatementList
;

compoundStatementList: (compoundStatement SEMICOLON_SYMBOL)+
;

caseStatement:
    CASE_SYMBOL expr? (whenExpression thenStatement)+ elseStatement? END_SYMBOL CASE_SYMBOL
;

elseStatement:
    ELSE_SYMBOL compoundStatementList
;

labeledBlock:
    label beginEndBlock labelRef?
;

unlabeledBlock:
    beginEndBlock
;

label:
    // Block labels can only be up to 16 characters long.
    labelIdentifier COLON_SYMBOL
;

beginEndBlock:
    BEGIN_SYMBOL spDeclarations? compoundStatementList? END_SYMBOL
;

labeledControl:
    label unlabeledControl labelRef?
;

unlabeledControl:
    loopBlock
    | whileDoBlock
    | repeatUntilBlock
;

loopBlock:
    LOOP_SYMBOL compoundStatementList END_SYMBOL LOOP_SYMBOL
;

whileDoBlock:
    WHILE_SYMBOL expr DO_SYMBOL compoundStatementList END_SYMBOL WHILE_SYMBOL
;

repeatUntilBlock:
    REPEAT_SYMBOL compoundStatementList UNTIL_SYMBOL expr END_SYMBOL REPEAT_SYMBOL
;

spDeclarations: (spDeclaration SEMICOLON_SYMBOL)+
;

spDeclaration:
    variableDeclaration
    | conditionDeclaration
    | handlerDeclaration
    | cursorDeclaration
;

variableDeclaration:
    DECLARE_SYMBOL identifierList dataType (COLLATE_SYMBOL collationName)? (
        DEFAULT_SYMBOL expr
    )?
;

conditionDeclaration:
    DECLARE_SYMBOL identifier CONDITION_SYMBOL FOR_SYMBOL spCondition
;

spCondition:
    ulong_number
    | sqlstate
;

sqlstate:
    SQLSTATE_SYMBOL VALUE_SYMBOL? textLiteral
;

handlerDeclaration:
    DECLARE_SYMBOL (CONTINUE_SYMBOL | EXIT_SYMBOL | UNDO_SYMBOL) HANDLER_SYMBOL FOR_SYMBOL handlerCondition (
        COMMA_SYMBOL handlerCondition
    )* compoundStatement
;

handlerCondition:
    spCondition
    | identifier
    | SQLWARNING_SYMBOL
    | notRule FOUND_SYMBOL
    | SQLEXCEPTION_SYMBOL
;

cursorDeclaration:
    DECLARE_SYMBOL identifier CURSOR_SYMBOL FOR_SYMBOL selectStatement
;

iterateStatement:
    ITERATE_SYMBOL labelRef
;

leaveStatement:
    LEAVE_SYMBOL labelRef
;

getDiagnostics:
    GET_SYMBOL (CURRENT_SYMBOL | {serverVersion >= 50700}? STACKED_SYMBOL)? DIAGNOSTICS_SYMBOL (
        statementInformationItem (COMMA_SYMBOL statementInformationItem)*
        | CONDITION_SYMBOL signalAllowedExpr conditionInformationItem (
            COMMA_SYMBOL conditionInformationItem
        )*
    )
;

// Only a limited subset of expr is allowed in SIGNAL/RESIGNAL/CONDITIONS.
signalAllowedExpr:
    literal
    | variable
    | qualifiedIdentifier
;

statementInformationItem:
    (variable | identifier) EQUAL_OPERATOR (NUMBER_SYMBOL | ROW_COUNT_SYMBOL)
;

conditionInformationItem:
    (variable | identifier) EQUAL_OPERATOR (
        signalInformationItemName
        | RETURNED_SQLSTATE_SYMBOL
    )
;

signalInformationItemName:
    CLASS_ORIGIN_SYMBOL
    | SUBCLASS_ORIGIN_SYMBOL
    | CONSTRAINT_CATALOG_SYMBOL
    | CONSTRAINT_SCHEMA_SYMBOL
    | CONSTRAINT_NAME_SYMBOL
    | CATALOG_NAME_SYMBOL
    | SCHEMA_NAME_SYMBOL
    | TABLE_NAME_SYMBOL
    | COLUMN_NAME_SYMBOL
    | CURSOR_NAME_SYMBOL
    | MESSAGE_TEXT_SYMBOL
    | MYSQL_ERRNO_SYMBOL
;

signalStatement:
    SIGNAL_SYMBOL (identifier | sqlstate) (
        SET_SYMBOL signalInformationItem (COMMA_SYMBOL signalInformationItem)*
    )?
;

resignalStatement:
    RESIGNAL_SYMBOL (SQLSTATE_SYMBOL VALUE_SYMBOL? textOrIdentifier)? (
        SET_SYMBOL signalInformationItem (COMMA_SYMBOL signalInformationItem)*
    )?
;

signalInformationItem:
    signalInformationItemName EQUAL_OPERATOR signalAllowedExpr
;

cursorOpen:
    OPEN_SYMBOL identifier
;

cursorClose:
    CLOSE_SYMBOL identifier
;

cursorFetch:
    FETCH_SYMBOL (NEXT_SYMBOL? FROM_SYMBOL)? identifier INTO_SYMBOL identifierList
;

//----------------- Supplemental rules -------------------------------------------------------------

// Schedules in CREATE/ALTER EVENT.
schedule:
    AT_SYMBOL expr
    | EVERY_SYMBOL expr interval (STARTS_SYMBOL expr)? (ENDS_SYMBOL expr)?
;

columnDefinition:
    columnName fieldDefinition checkOrReferences?
;

checkOrReferences:
    checkConstraint
    | references
;

checkConstraint:
    CHECK_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL
;

tableConstraintDef:
    type = (KEY_SYMBOL | INDEX_SYMBOL) indexNameAndType? keyList indexOption*
    | type = FULLTEXT_SYMBOL keyOrIndex? indexName? keyList fulltextIndexOption*
    | type = SPATIAL_SYMBOL keyOrIndex? indexName? keyList spatialIndexOption*
    | (CONSTRAINT_SYMBOL identifier?)? (
        type = PRIMARY_SYMBOL KEY_SYMBOL indexNameAndType? keyList indexOption*
        | type = UNIQUE_SYMBOL keyOrIndex? indexNameAndType? keyList indexOption*
        | type = FOREIGN_SYMBOL KEY_SYMBOL indexName? keyList references
        | checkConstraint
    )
;

fieldDefinition:
    dataType (
        columnAttribute*
        | {serverVersion >= 50707}? (COLLATE_SYMBOL collationName)? (
            GENERATED_SYMBOL ALWAYS_SYMBOL
        )? AS_SYMBOL OPEN_PAR_SYMBOL expr CLOSE_PAR_SYMBOL (
            VIRTUAL_SYMBOL
            | STORED_SYMBOL
        )? (
            {serverVersion < 80000}? gcolAttribute*
            | {serverVersion >= 80000}? columnAttribute* // Beginning with 8.0 the full attribute set is supported.
        )
    )
;

columnAttribute:
    NOT_SYMBOL? nullLiteral
    | value = DEFAULT_SYMBOL (signedLiteral | NOW_SYMBOL timeFunctionParameters?)
    | value = ON_SYMBOL UPDATE_SYMBOL NOW_SYMBOL timeFunctionParameters?
    | value = AUTO_INCREMENT_SYMBOL
    | value = SERIAL_SYMBOL DEFAULT_SYMBOL VALUE_SYMBOL
    | value = UNIQUE_SYMBOL KEY_SYMBOL?
    | PRIMARY_SYMBOL? value = KEY_SYMBOL
    | value = COMMENT_SYMBOL textLiteral
    | value = COLLATE_SYMBOL collationName
    | value = COLUMN_FORMAT_SYMBOL (FIXED_SYMBOL | DYNAMIC_SYMBOL | DEFAULT_SYMBOL)
    | value = STORAGE_SYMBOL (DISK_SYMBOL | MEMORY_SYMBOL | DEFAULT_SYMBOL)
    | {serverVersion >= 80000}? SRID_SYMBOL real_ulonglong_number
;

gcolAttribute:
    UNIQUE_SYMBOL KEY_SYMBOL?
    | COMMENT_SYMBOL textString
    | notRule? NULL_SYMBOL
    | PRIMARY_SYMBOL? KEY_SYMBOL
;

references:
    REFERENCES_SYMBOL tableRef identifierListWithParentheses? (
        MATCH_SYMBOL match = (FULL_SYMBOL | PARTIAL_SYMBOL | SIMPLE_SYMBOL)
    )? (
        ON_SYMBOL option = UPDATE_SYMBOL deleteOption (
            ON_SYMBOL DELETE_SYMBOL deleteOption
        )?
        | ON_SYMBOL option = DELETE_SYMBOL deleteOption (
            ON_SYMBOL UPDATE_SYMBOL deleteOption
        )?
    )?
;

deleteOption:
    (RESTRICT_SYMBOL | CASCADE_SYMBOL)
    | SET_SYMBOL nullLiteral
    | NO_SYMBOL ACTION_SYMBOL
;

keyList:
    OPEN_PAR_SYMBOL keyPart (COMMA_SYMBOL keyPart)* CLOSE_PAR_SYMBOL
;

keyPart:
    identifier fieldLength? direction?
;

indexType:
    algorithm = (BTREE_SYMBOL | RTREE_SYMBOL | HASH_SYMBOL)
;

indexOption:
    commonIndexOption
    | indexTypeClause
;

// These options are common for all index types.
commonIndexOption:
    KEY_BLOCK_SIZE_SYMBOL EQUAL_OPERATOR? ulong_number
    | {serverVersion >= 50600}? COMMENT_SYMBOL textLiteral
    | {serverVersion >= 80000}? visibility
;

visibility:
    VISIBLE_SYMBOL
    | INVISIBLE_SYMBOL
;

indexTypeClause: (USING_SYMBOL | TYPE_SYMBOL) indexType
;

fulltextIndexOption:
    commonIndexOption
    | WITH_SYMBOL PARSER_SYMBOL identifier
;

spatialIndexOption:
    commonIndexOption
;

dataTypeDefinition: // For external use only. Don't reference this in the normal grammar.
    dataType EOF
;

dataType:
    type = (
        INT_SYMBOL
        | TINYINT_SYMBOL
        | SMALLINT_SYMBOL
        | MEDIUMINT_SYMBOL
        | BIGINT_SYMBOL
    ) fieldLength? fieldOptions?
    | (type = REAL_SYMBOL | type = DOUBLE_SYMBOL PRECISION_SYMBOL?) precision? fieldOptions?
    | type = (FLOAT_SYMBOL | DECIMAL_SYMBOL | NUMERIC_SYMBOL | FIXED_SYMBOL) floatOptions? fieldOptions?
    | type = BIT_SYMBOL fieldLength?
    | type = (BOOL_SYMBOL | BOOLEAN_SYMBOL)
    | type = CHAR_SYMBOL fieldLength? charsetWithOptBinary?
    | nchar fieldLength? BINARY_SYMBOL?
    | type = BINARY_SYMBOL fieldLength?
    | (type = CHAR_SYMBOL VARYING_SYMBOL | type = VARCHAR_SYMBOL) fieldLength charsetWithOptBinary?
    | (
        type = NATIONAL_SYMBOL VARCHAR_SYMBOL
        | type = NVARCHAR_SYMBOL
        | type = NCHAR_SYMBOL VARCHAR_SYMBOL
        | type = NATIONAL_SYMBOL CHAR_SYMBOL VARYING_SYMBOL
        | type = NCHAR_SYMBOL VARYING_SYMBOL
    ) fieldLength BINARY_SYMBOL?
    | type = VARBINARY_SYMBOL fieldLength
    | type = YEAR_SYMBOL fieldLength? fieldOptions?
    | type = DATE_SYMBOL
    | type = TIME_SYMBOL typeDatetimePrecision?
    | type = TIMESTAMP_SYMBOL typeDatetimePrecision?
    | type = DATETIME_SYMBOL typeDatetimePrecision?
    | type = TINYBLOB_SYMBOL
    | type = BLOB_SYMBOL fieldLength?
    | type = (MEDIUMBLOB_SYMBOL | LONGBLOB_SYMBOL)
    | type = LONG_SYMBOL VARBINARY_SYMBOL
    | type = LONG_SYMBOL (CHAR_SYMBOL VARYING_SYMBOL | VARCHAR_SYMBOL)? charsetWithOptBinary?
    | type = TINYTEXT_SYMBOL charsetWithOptBinary?
    | type = TEXT_SYMBOL fieldLength? charsetWithOptBinary?
    | type = MEDIUMTEXT_SYMBOL charsetWithOptBinary?
    | type = LONGTEXT_SYMBOL charsetWithOptBinary?
    | type = ENUM_SYMBOL stringList charsetWithOptBinary?
    | type = SET_SYMBOL stringList charsetWithOptBinary?
    | type = SERIAL_SYMBOL
    | {serverVersion >= 50708}? type = JSON_SYMBOL
    | type = (
        GEOMETRY_SYMBOL
        | GEOMETRYCOLLECTION_SYMBOL
        | POINT_SYMBOL
        | MULTIPOINT_SYMBOL
        | LINESTRING_SYMBOL
        | MULTILINESTRING_SYMBOL
        | POLYGON_SYMBOL
        | MULTIPOLYGON_SYMBOL
    )
;

nchar:
    type = NCHAR_SYMBOL
    | type = NATIONAL_SYMBOL CHAR_SYMBOL
;

varchar:
    type = CHAR_SYMBOL VARYING_SYMBOL
    | type = VARCHAR_SYMBOL
;

nvarchar:
    type = NATIONAL_SYMBOL VARCHAR_SYMBOL
    | type = NVARCHAR_SYMBOL
    | type = NCHAR_SYMBOL VARCHAR_SYMBOL
    | type = NATIONAL_SYMBOL CHAR_SYMBOL VARYING_SYMBOL
    | type = NCHAR_SYMBOL VARYING_SYMBOL
;

fieldLength:
    OPEN_PAR_SYMBOL (real_ulonglong_number | DECIMAL_NUMBER) CLOSE_PAR_SYMBOL
;

fieldOptions: (SIGNED_SYMBOL | UNSIGNED_SYMBOL | ZEROFILL_SYMBOL)+
;

charsetWithOptBinary:
    ascii
    | unicode
    | BYTE_SYMBOL
    | charset charsetName BINARY_SYMBOL?
    | BINARY_SYMBOL (charset charsetName)?
;

ascii:
    ASCII_SYMBOL BINARY_SYMBOL?
    | BINARY_SYMBOL ASCII_SYMBOL
;

unicode:
    UNICODE_SYMBOL BINARY_SYMBOL?
    | BINARY_SYMBOL UNICODE_SYMBOL
;

wsNumCodepoints:
    OPEN_PAR_SYMBOL real_ulong_number CLOSE_PAR_SYMBOL
;

typeDatetimePrecision:
    {serverVersion >= 50600}? OPEN_PAR_SYMBOL INT_NUMBER CLOSE_PAR_SYMBOL
;

charsetName:
    textOrIdentifier
    | BINARY_SYMBOL
    | {serverVersion < 80011}? DEFAULT_SYMBOL
;

collationName:
    textOrIdentifier
    | {serverVersion < 80011}? DEFAULT_SYMBOL
;

createTableOptions:
    createTableOption (COMMA_SYMBOL? createTableOption)*
;

createTableOptionsSpaceSeparated:
    createTableOption+
;

createTableOption: // In the order as they appear in the server grammar.
    option = ENGINE_SYMBOL EQUAL_OPERATOR? engineRef
    | option = MAX_ROWS_SYMBOL EQUAL_OPERATOR? ulonglong_number
    | option = MIN_ROWS_SYMBOL EQUAL_OPERATOR? ulonglong_number
    | option = AVG_ROW_LENGTH_SYMBOL EQUAL_OPERATOR? ulong_number
    | option = PASSWORD_SYMBOL EQUAL_OPERATOR? textStringLiteral
    | option = COMMENT_SYMBOL EQUAL_OPERATOR? textStringLiteral
    | {serverVersion >= 50708}? option = COMPRESSION_SYMBOL EQUAL_OPERATOR? textString
    | {serverVersion >= 50711}? option = ENCRYPTION_SYMBOL EQUAL_OPERATOR? textString
    | option = AUTO_INCREMENT_SYMBOL EQUAL_OPERATOR? ulonglong_number
    | option = PACK_KEYS_SYMBOL EQUAL_OPERATOR? ternaryOption
    | {serverVersion >= 50600}? option = (
        STATS_AUTO_RECALC_SYMBOL
        | STATS_PERSISTENT_SYMBOL
        | STATS_SAMPLE_PAGES_SYMBOL
    ) EQUAL_OPERATOR? ternaryOption
    | option = (CHECKSUM_SYMBOL | TABLE_CHECKSUM_SYMBOL) EQUAL_OPERATOR? ulong_number
    | option = DELAY_KEY_WRITE_SYMBOL EQUAL_OPERATOR? ulong_number
    | option = ROW_FORMAT_SYMBOL EQUAL_OPERATOR? format = (
        DEFAULT_SYMBOL
        | DYNAMIC_SYMBOL
        | FIXED_SYMBOL
        | COMPRESSED_SYMBOL
        | REDUNDANT_SYMBOL
        | COMPACT_SYMBOL
    )
    | option = UNION_SYMBOL EQUAL_OPERATOR? OPEN_PAR_SYMBOL tableRefList CLOSE_PAR_SYMBOL
    | defaultCharset
    | defaultCollation
    | option = INSERT_METHOD_SYMBOL EQUAL_OPERATOR? method = (
        NO_SYMBOL
        | FIRST_SYMBOL
        | LAST_SYMBOL
    )
    | option = DATA_SYMBOL DIRECTORY_SYMBOL EQUAL_OPERATOR? textString
    | option = INDEX_SYMBOL DIRECTORY_SYMBOL EQUAL_OPERATOR? textString
    | option = TABLESPACE_SYMBOL (
        {serverVersion >= 50707}? EQUAL_OPERATOR?
        | /* empty */
    ) identifier
    | option = STORAGE_SYMBOL (DISK_SYMBOL | MEMORY_SYMBOL)
    | option = CONNECTION_SYMBOL EQUAL_OPERATOR? textString
    | option = KEY_BLOCK_SIZE_SYMBOL EQUAL_OPERATOR? ulong_number
;

ternaryOption:
    ulong_number
    | DEFAULT_SYMBOL
;

defaultCollation:
    DEFAULT_SYMBOL? COLLATE_SYMBOL EQUAL_OPERATOR? collationName
;

defaultCharset:
    DEFAULT_SYMBOL? charset EQUAL_OPERATOR? charsetName
;

// Partition rules for CREATE/ALTER TABLE.
partitionClause:
    PARTITION_SYMBOL BY_SYMBOL partitionTypeDef (PARTITIONS_SYMBOL real_ulong_number)? subPartitions? partitionDefinitions?
;

partitionTypeDef:
    LINEAR_SYMBOL? KEY_SYMBOL partitionKeyAlgorithm? OPEN_PAR_SYMBOL identifierList? CLOSE_PAR_SYMBOL # partitionDefKey
    | LINEAR_SYMBOL? HASH_SYMBOL OPEN_PAR_SYMBOL bitExpr CLOSE_PAR_SYMBOL                             # partitionDefHash
    | (RANGE_SYMBOL | LIST_SYMBOL) (
        OPEN_PAR_SYMBOL bitExpr CLOSE_PAR_SYMBOL
        | COLUMNS_SYMBOL OPEN_PAR_SYMBOL identifierList? CLOSE_PAR_SYMBOL
    ) # partitionDefRangeList
;

subPartitions:
    SUBPARTITION_SYMBOL BY_SYMBOL LINEAR_SYMBOL? (
        HASH_SYMBOL OPEN_PAR_SYMBOL bitExpr CLOSE_PAR_SYMBOL
        | KEY_SYMBOL partitionKeyAlgorithm? identifierListWithParentheses
    ) (SUBPARTITIONS_SYMBOL real_ulong_number)?
;

partitionKeyAlgorithm: // Actually only 1 and 2 are allowed. Needs a semantic check.
    {serverVersion >= 50700}? ALGORITHM_SYMBOL EQUAL_OPERATOR real_ulong_number
;

partitionDefinitions:
    OPEN_PAR_SYMBOL partitionDefinition (COMMA_SYMBOL partitionDefinition)* CLOSE_PAR_SYMBOL
;

partitionDefinition:
    PARTITION_SYMBOL identifier (
        VALUES_SYMBOL LESS_SYMBOL THAN_SYMBOL (
            partitionValueItemListParen
            | MAXVALUE_SYMBOL
        )
        | VALUES_SYMBOL IN_SYMBOL partitionValuesIn
    )? partitionOption* (
        OPEN_PAR_SYMBOL subpartitionDefinition (COMMA_SYMBOL subpartitionDefinition)* CLOSE_PAR_SYMBOL
    )?
;

partitionValuesIn:
    partitionValueItemListParen
    | OPEN_PAR_SYMBOL partitionValueItemListParen (
        COMMA_SYMBOL partitionValueItemListParen
    )* CLOSE_PAR_SYMBOL
;

partitionOption:
    option = TABLESPACE_SYMBOL EQUAL_OPERATOR? identifier
    | option = STORAGE_SYMBOL? ENGINE_SYMBOL EQUAL_OPERATOR? engineRef
    | option = NODEGROUP_SYMBOL EQUAL_OPERATOR? real_ulong_number
    | option = (MAX_ROWS_SYMBOL | MIN_ROWS_SYMBOL) EQUAL_OPERATOR? real_ulong_number
    | option = (DATA_SYMBOL | INDEX_SYMBOL) DIRECTORY_SYMBOL EQUAL_OPERATOR? textLiteral
    | option = COMMENT_SYMBOL EQUAL_OPERATOR? textLiteral
;

subpartitionDefinition:
    SUBPARTITION_SYMBOL textOrIdentifier partitionOption*
;

partitionValueItemListParen:
    OPEN_PAR_SYMBOL partitionValueItem (COMMA_SYMBOL partitionValueItem)* CLOSE_PAR_SYMBOL
;

partitionValueItem:
    bitExpr
    | MAXVALUE_SYMBOL
;

definerClause:
    DEFINER_SYMBOL EQUAL_OPERATOR user
;

ifExists:
    IF_SYMBOL EXISTS_SYMBOL
;

ifNotExists:
    IF_SYMBOL notRule EXISTS_SYMBOL
;

procedureParameter:
    type = (IN_SYMBOL | OUT_SYMBOL | INOUT_SYMBOL)? functionParameter
;

functionParameter:
    parameterName typeWithOptCollate
;

typeWithOptCollate:
    dataType (COLLATE_SYMBOL collationName)?
;

schemaIdentifierPair:
    OPEN_PAR_SYMBOL schemaRef COMMA_SYMBOL schemaRef CLOSE_PAR_SYMBOL
;

viewRefList:
    viewRef (COMMA_SYMBOL viewRef)*
;

updateList:
    updateElement (COMMA_SYMBOL updateElement)*
;

updateElement:
    columnRef EQUAL_OPERATOR (expr | DEFAULT_SYMBOL)
;

charsetClause:
    charset charsetName
;

fieldsClause:
    COLUMNS_SYMBOL fieldTerm+
;

fieldTerm:
    TERMINATED_SYMBOL BY_SYMBOL textString
    | OPTIONALLY_SYMBOL? ENCLOSED_SYMBOL BY_SYMBOL textString
    | ESCAPED_SYMBOL BY_SYMBOL textString
;

linesClause:
    LINES_SYMBOL lineTerm+
;

lineTerm: (TERMINATED_SYMBOL | STARTING_SYMBOL) BY_SYMBOL textString
;

userList:
    user (COMMA_SYMBOL user)*
;

createOrAlterUserList:
    createOrAlterUser (COMMA_SYMBOL createOrAlterUser)*
;

createOrAlterUser:
    user (
        IDENTIFIED_SYMBOL (
            BY_SYMBOL ({serverVersion < 80011}? PASSWORD_SYMBOL)? textString
            | {serverVersion >= 50600}? WITH_SYMBOL textOrIdentifier (
                (AS_SYMBOL | {serverVersion >= 50706}? BY_SYMBOL) textString
            )?
        )
    )?
;

user:
    textOrIdentifier (AT_SIGN_SYMBOL textOrIdentifier | AT_TEXT_SUFFIX)?
    | CURRENT_USER_SYMBOL parentheses?
;

likeClause:
    LIKE_SYMBOL textStringLiteral
;

likeOrWhere:
    likeClause
    | whereClause
;

onlineOption:
    {serverVersion < 50600}? (ONLINE_SYMBOL | OFFLINE_SYMBOL)
;

noWriteToBinLog:
    LOCAL_SYMBOL
    | NO_WRITE_TO_BINLOG_SYMBOL
;

usePartition:
    {serverVersion >= 50602}? PARTITION_SYMBOL identifierListWithParentheses
;

//----------------- Object names and references ----------------------------------------------------

// For each object we have at least 2 rules here:
// 1) The name when creating that object.
// 2) The name when used to reference it from other rules.
//
// Sometimes we need additional reference rules with different form, depending on the place such a reference is used.

// A name for a field (column/index). Can be qualified with the current schema + table (although it's not a reference).
fieldIdentifier:
    dotIdentifier
    | qualifiedIdentifier dotIdentifier?
;

columnName:
    // With server 8.0 this became a simple identifier.
    {serverVersion >= 80000}? identifier
    | {serverVersion < 80000}? fieldIdentifier
;

// A reference to a column of the object we are working on.
columnInternalRef:
    identifier
;

columnInternalRefList: // column_list in sql_yacc.yy
    OPEN_PAR_SYMBOL columnInternalRef (COMMA_SYMBOL columnInternalRef)* CLOSE_PAR_SYMBOL
;

columnRef: // A field identifier that can reference any schema/table.
    fieldIdentifier
;

insertIdentifier:
    columnRef
    | tableWild
;

indexName:
    identifier
;

indexRef: // Always internal reference. Still all qualification variations are accepted.
    fieldIdentifier
;

tableWild:
    identifier DOT_SYMBOL (identifier DOT_SYMBOL)? MULT_OPERATOR
;

schemaName:
    identifier
;

schemaRef:
    identifier
;

procedureName:
    qualifiedIdentifier
;

procedureRef:
    qualifiedIdentifier
;

functionName:
    qualifiedIdentifier
;

functionRef:
    qualifiedIdentifier
;

triggerName:
    qualifiedIdentifier
;

triggerRef:
    qualifiedIdentifier
;

viewName:
    qualifiedIdentifier
    | dotIdentifier
;

viewRef:
    qualifiedIdentifier
    | dotIdentifier
;

tablespaceName:
    identifier
;

tablespaceRef:
    identifier
;

logfileGroupName:
    identifier
;

logfileGroupRef:
    identifier
;

eventName:
    qualifiedIdentifier
;

eventRef:
    qualifiedIdentifier
;

udfName: // UDFs are referenced at the same places as any other function. So, no dedicated *_ref here.
    identifier
;

serverName:
    textOrIdentifier
;

serverRef:
    textOrIdentifier
;

engineRef:
    textOrIdentifier
;

tableName:
    qualifiedIdentifier
    | dotIdentifier
;

filterTableRef: // Always qualified.
    identifier dotIdentifier
;

tableRefWithWildcard:
    identifier (DOT_SYMBOL MULT_OPERATOR | dotIdentifier (DOT_SYMBOL MULT_OPERATOR)?)?
;

tableRef:
    qualifiedIdentifier
    | dotIdentifier
;

tableRefList:
    tableRef (COMMA_SYMBOL tableRef)*
;

tableAliasRefList:
    tableRefWithWildcard (COMMA_SYMBOL tableRefWithWildcard)*
;

parameterName:
    identifier
;

labelIdentifier:
    pureIdentifier
    | labelKeyword
;

labelRef:
    labelIdentifier
;

roleIdentifier:
    pureIdentifier
    | roleKeyword
;

roleRef:
    roleIdentifier
;

pluginRef:
    identifier
;

componentRef:
    textStringLiteral
;

resourceGroupRef:
    identifier
;

windowName:
    identifier
;

//----------------- Common basic rules -------------------------------------------------------------

// Identifiers excluding keywords (except if they are quoted). IDENT_sys in sql_yacc.yy.
pureIdentifier:
    (IDENTIFIER | BACK_TICK_QUOTED_ID)
    | {isSqlModeActive(AnsiQuotes)}? DOUBLE_QUOTED_TEXT
;

// Identifiers including a certain set of keywords, which are allowed also if not quoted.
// ident in sql_yacc.yy
identifier:
    pureIdentifier
    | identifierKeyword
;

identifierList: // ident_string_list in sql_yacc.yy.
    identifier (COMMA_SYMBOL identifier)*
;

identifierListWithParentheses:
    OPEN_PAR_SYMBOL identifierList CLOSE_PAR_SYMBOL
;

qualifiedIdentifier:
    identifier dotIdentifier?
;

simpleIdentifier: // simple_ident + simple_ident_q
    identifier (dotIdentifier dotIdentifier?)?
    | {serverVersion < 80000}? dotIdentifier dotIdentifier
;

// This rule encapsulates the frequently used dot + identifier sequence, which also requires a special
// treatment in the lexer. See there in the DOT_IDENTIFIER rule.
dotIdentifier:
    DOT_SYMBOL identifier
;

ulong_number:
    INT_NUMBER
    | HEX_NUMBER
    | LONG_NUMBER
    | ULONGLONG_NUMBER
    | DECIMAL_NUMBER
    | FLOAT_NUMBER
;

real_ulong_number:
    INT_NUMBER
    | HEX_NUMBER
    | LONG_NUMBER
    | ULONGLONG_NUMBER
;

ulonglong_number:
    INT_NUMBER
    | LONG_NUMBER
    | ULONGLONG_NUMBER
    | DECIMAL_NUMBER
    | FLOAT_NUMBER
;

real_ulonglong_number:
    INT_NUMBER
    | ULONGLONG_NUMBER
    | LONG_NUMBER
;

literal:
    textLiteral
    | numLiteral
    | temporalLiteral
    | nullLiteral
    | boolLiteral
    | UNDERSCORE_CHARSET? (HEX_NUMBER | BIN_NUMBER)
;

signedLiteral:
    literal
    | PLUS_OPERATOR ulong_number
    | MINUS_OPERATOR ulong_number
;

stringList:
    OPEN_PAR_SYMBOL textString (COMMA_SYMBOL textString)* CLOSE_PAR_SYMBOL
;

textStringLiteral: // TEXT_STRING_sys + TEXT_STRING_literal + TEXT_STRING_filesystem + TEXT_STRING in sql_yacc.yy.
    value = SINGLE_QUOTED_TEXT
    | {!isSqlModeActive(AnsiQuotes)}? value = DOUBLE_QUOTED_TEXT
;

textString:
    textStringLiteral
    | HEX_NUMBER
    | BIN_NUMBER
;

textLiteral:
    (UNDERSCORE_CHARSET? textStringLiteral | NCHAR_TEXT) textStringLiteral*
;

// A special variant of a text string that must not contain a linebreak (TEXT_STRING_sys_nonewline in sql_yacc.yy).
// Check validity in semantic phase.
textStringNoLinebreak:
    textStringLiteral
;

textStringLiteralList:
    textStringLiteral (COMMA_SYMBOL textStringLiteral)*
;

numLiteral:
    INT_NUMBER
    | LONG_NUMBER
    | ULONGLONG_NUMBER
    | DECIMAL_NUMBER
    | FLOAT_NUMBER
;

boolLiteral:
    TRUE_SYMBOL
    | FALSE_SYMBOL
;

nullLiteral: // In sql_yacc.cc both 'NULL' and '\N' are mapped to NULL_SYM (which is our nullLiteral).
    NULL_SYMBOL
    | NULL2_SYMBOL
;

temporalLiteral:
    DATE_SYMBOL SINGLE_QUOTED_TEXT
    | TIME_SYMBOL SINGLE_QUOTED_TEXT
    | TIMESTAMP_SYMBOL SINGLE_QUOTED_TEXT
;

floatOptions:
    fieldLength
    | precision
;

precision:
    OPEN_PAR_SYMBOL INT_NUMBER COMMA_SYMBOL INT_NUMBER CLOSE_PAR_SYMBOL
;

textOrIdentifier:
    SINGLE_QUOTED_TEXT
    | identifier
    //| AT_TEXT_SUFFIX // LEX_HOSTNAME in the server grammar. Handled differently.
;

roleIdentifierOrText:
    roleIdentifier
    | textStringLiteral
    // also here LEX_HOSTNAME
;

sizeNumber:
    real_ulonglong_number
    | pureIdentifier // Something like 10G. Semantic check needed for validity.
;

parentheses:
    OPEN_PAR_SYMBOL CLOSE_PAR_SYMBOL
;

equal:
    EQUAL_OPERATOR
    | ASSIGN_OPERATOR
;

// PERSIST and PERSIST_ONLY are conditionally handled in the lexer. Hence no predicate required here.
optionType:
    PERSIST_SYMBOL
    | PERSIST_ONLY_SYMBOL
    | GLOBAL_SYMBOL
    | LOCAL_SYMBOL
    | SESSION_SYMBOL
;

varIdentType:
    GLOBAL_SYMBOL DOT_SYMBOL
    | LOCAL_SYMBOL DOT_SYMBOL
    | SESSION_SYMBOL DOT_SYMBOL
;

setVarIdentType:
    PERSIST_SYMBOL DOT_SYMBOL
    | PERSIST_ONLY_SYMBOL DOT_SYMBOL
    | GLOBAL_SYMBOL DOT_SYMBOL
    | LOCAL_SYMBOL DOT_SYMBOL
    | SESSION_SYMBOL DOT_SYMBOL
;

// Non-reserved keywords that we allow for identifiers (except SP labels).
//
// Also see statement-specific rules:
//   * label_keyword,
//   * role_keyword
//
// We allow the use of some non-reserved keywords as identifiers, SP labels and
// roles, but the three sets of keywords are different and yet
// overlapping. Hence we need a somewhat complicated set of rules for all
// possible intersections of these sets: role_or_ident_keyword,
// role_or_label_keyword.
identifierKeyword:
    labelKeyword
    | roleOrIdentifierKeyword
    | EXECUTE_SYMBOL
    | {serverVersion >= 50709}? SHUTDOWN_SYMBOL // Previously allowed as SP label as well.
    | {serverVersion >= 80011}? RESTART_SYMBOL
;

// Keywords that we allow for labels in SPs.
labelKeyword:
    roleOrLabelKeyword
    | EVENT_SYMBOL
    | FILE_SYMBOL
    | NONE_SYMBOL
    | PROCESS_SYMBOL
    | PROXY_SYMBOL
    | RELOAD_SYMBOL
    | REPLICATION_SYMBOL
    | RESOURCE_SYMBOL // Conditionally set in the lexer.
    | SUPER_SYMBOL
;

// $antlr-format groupedAlignments off

// These are the non-reserved keywords which may be used for roles or idents.
// Keywords defined only for specific server versions are handled at lexer level and so cannot match this rule
// if the current server version doesn't allow them. Hence we don't need predicates here for them.
roleOrIdentifierKeyword:
    (
        ACCOUNT_SYMBOL                  // Conditionally set in the lexer.
        | ASCII_SYMBOL
        | ALWAYS_SYMBOL                 // Conditionally set in the lexer.
        | BACKUP_SYMBOL
        | BEGIN_SYMBOL
        | BYTE_SYMBOL
        | CACHE_SYMBOL
        | CHARSET_SYMBOL
        | CHECKSUM_SYMBOL
        | CLONE_SYMBOL                  // Conditionally set in the lexer.
        | CLOSE_SYMBOL
        | COMMENT_SYMBOL
        | COMMIT_SYMBOL
        | CONTAINS_SYMBOL
        | DEALLOCATE_SYMBOL
        | DO_SYMBOL
        | END_SYMBOL
        | FLUSH_SYMBOL
        | FOLLOWS_SYMBOL
        | FORMAT_SYMBOL
        | GROUP_REPLICATION_SYMBOL      // Conditionally set in the lexer.
        | HANDLER_SYMBOL
        | HELP_SYMBOL
        | HOST_SYMBOL
        | INSTALL_SYMBOL
        | INVISIBLE_SYMBOL              // Conditionally set in the lexer.
        | LANGUAGE_SYMBOL
        | NO_SYMBOL
        | OPEN_SYMBOL
        | OPTIONS_SYMBOL
        | OWNER_SYMBOL
        | PARSER_SYMBOL
        | PARTITION_SYMBOL
        | PORT_SYMBOL
        | PRECEDES_SYMBOL
        | PREPARE_SYMBOL
        | REMOVE_SYMBOL
        | REPAIR_SYMBOL
        | RESET_SYMBOL
        | RESTORE_SYMBOL
        | ROLE_SYMBOL                   // Conditionally set in the lexer.
        | ROLLBACK_SYMBOL
        | SAVEPOINT_SYMBOL
        | SECURITY_SYMBOL
        | SERVER_SYMBOL
        | SIGNED_SYMBOL
        | SOCKET_SYMBOL
        | SLAVE_SYMBOL
        | SONAME_SYMBOL
        | START_SYMBOL
        | STOP_SYMBOL
        | TRUNCATE_SYMBOL
        | UNICODE_SYMBOL
        | UNINSTALL_SYMBOL
        | UPGRADE_SYMBOL
        | VISIBLE_SYMBOL                // Conditionally set in the lexer.
        | WRAPPER_SYMBOL
        | XA_SYMBOL
    )
    // Rules that entered or left this rule in specific versions.
    | {serverVersion >= 50709}? SHUTDOWN_SYMBOL
    | {serverVersion >= 80000}? IMPORT_SYMBOL
;

roleOrLabelKeyword:
    (
        ACTION_SYMBOL
        | ADDDATE_SYMBOL
        | AFTER_SYMBOL
        | AGAINST_SYMBOL
        | AGGREGATE_SYMBOL
        | ALGORITHM_SYMBOL
        | ANALYSE_SYMBOL                // Conditionally set in the lexer.
        | ANY_SYMBOL
        | AT_SYMBOL
        | AUTHORS_SYMBOL                // Conditionally set in the lexer.
        | AUTO_INCREMENT_SYMBOL
        | AUTOEXTEND_SIZE_SYMBOL
        | AVG_ROW_LENGTH_SYMBOL
        | AVG_SYMBOL
        | BINLOG_SYMBOL
        | BIT_SYMBOL
        | BLOCK_SYMBOL
        | BOOL_SYMBOL
        | BOOLEAN_SYMBOL
        | BTREE_SYMBOL
        | BUCKETS_SYMBOL                // Conditionally set in the lexer.
        | CASCADED_SYMBOL
        | CATALOG_NAME_SYMBOL
        | CHAIN_SYMBOL
        | CHANGED_SYMBOL
        | CHANNEL_SYMBOL                // Conditionally set in the lexer.
        | CIPHER_SYMBOL
        | CLIENT_SYMBOL
        | CLASS_ORIGIN_SYMBOL
        | COALESCE_SYMBOL
        | CODE_SYMBOL
        | COLLATION_SYMBOL
        | COLUMN_NAME_SYMBOL
        | COLUMN_FORMAT_SYMBOL
        | COLUMNS_SYMBOL
        | COMMITTED_SYMBOL
        | COMPACT_SYMBOL
        | COMPLETION_SYMBOL
        | COMPONENT_SYMBOL
        | COMPRESSED_SYMBOL             // Conditionally set in the lexer.
        | COMPRESSION_SYMBOL            // Conditionally set in the lexer.
        | ENCRYPTION_SYMBOL             // Conditionally set in the lexer.
        | CONCURRENT_SYMBOL
        | CONNECTION_SYMBOL
        | CONSISTENT_SYMBOL
        | CONSTRAINT_CATALOG_SYMBOL
        | CONSTRAINT_SCHEMA_SYMBOL
        | CONSTRAINT_NAME_SYMBOL
        | CONTEXT_SYMBOL
        | CONTRIBUTORS_SYMBOL           // Conditionally set in the lexer.
        | CPU_SYMBOL
        /*
          Although a reserved keyword in SQL:2003 (and :2008),
          not reserved in MySQL per WL#2111 specification.
        */
        | CURRENT_SYMBOL
        | CURSOR_NAME_SYMBOL
        | DATA_SYMBOL
        | DATAFILE_SYMBOL
        | DATETIME_SYMBOL
        | DATE_SYMBOL
        | DAY_SYMBOL
        | DEFAULT_AUTH_SYMBOL
        | DEFINER_SYMBOL
        | DELAY_KEY_WRITE_SYMBOL
        | DES_KEY_FILE_SYMBOL           // Conditionally set in the lexer.
        | DESCRIPTION_SYMBOL            // Conditionally set in the lexer.
        | DIAGNOSTICS_SYMBOL
        | DIRECTORY_SYMBOL
        | DISABLE_SYMBOL
        | DISCARD_SYMBOL
        | DISK_SYMBOL
        | DUMPFILE_SYMBOL
        | DUPLICATE_SYMBOL
        | DYNAMIC_SYMBOL
        | ENDS_SYMBOL
        | ENUM_SYMBOL
        | ENGINE_SYMBOL
        | ENGINES_SYMBOL
        | ERROR_SYMBOL
        | ERRORS_SYMBOL
        | ESCAPE_SYMBOL
        | EVENTS_SYMBOL
        | EVERY_SYMBOL
        | EXCLUDE_SYMBOL                // Conditionally set in the lexer.
        | EXPANSION_SYMBOL
        | EXPORT_SYMBOL
        | EXTENDED_SYMBOL
        | EXTENT_SIZE_SYMBOL
        | FAULTS_SYMBOL
        | FAST_SYMBOL
        | FOLLOWING_SYMBOL              // Conditionally set in the lexer.
        | FOUND_SYMBOL
        | ENABLE_SYMBOL
        | FULL_SYMBOL
        | FILE_BLOCK_SIZE_SYMBOL        // Conditionally set in the lexer.
        | FILTER_SYMBOL
        | FIRST_SYMBOL
        | FIXED_SYMBOL
        | GENERAL_SYMBOL
        | GEOMETRY_SYMBOL
        | GEOMETRYCOLLECTION_SYMBOL
        | GET_FORMAT_SYMBOL
        | GRANTS_SYMBOL
        | GLOBAL_SYMBOL
        | HASH_SYMBOL
        | HISTOGRAM_SYMBOL              // Conditionally set in the lexer.
        | HISTORY_SYMBOL                // Conditionally set in the lexer.
        | HOSTS_SYMBOL
        | HOUR_SYMBOL
        | IDENTIFIED_SYMBOL
        | IGNORE_SERVER_IDS_SYMBOL
        | INVOKER_SYMBOL
        | INDEXES_SYMBOL
        | INITIAL_SIZE_SYMBOL
        | INSTANCE_SYMBOL               // Conditionally deprecated in the lexer.
        | IO_SYMBOL
        | IPC_SYMBOL
        | ISOLATION_SYMBOL
        | ISSUER_SYMBOL
        | INSERT_METHOD_SYMBOL
        | JSON_SYMBOL                   // Conditionally set in the lexer.
        | KEY_BLOCK_SIZE_SYMBOL
        | LAST_SYMBOL
        | LEAVES_SYMBOL
        | LESS_SYMBOL
        | LEVEL_SYMBOL
        | LINESTRING_SYMBOL
        | LIST_SYMBOL
        | LOCAL_SYMBOL
        | LOCKED_SYMBOL                 // Conditionally set in the lexer.
        | LOCKS_SYMBOL
        | LOGFILE_SYMBOL
        | LOGS_SYMBOL
        | MAX_ROWS_SYMBOL
        | MASTER_SYMBOL
        | MASTER_HEARTBEAT_PERIOD_SYMBOL
        | MASTER_HOST_SYMBOL
        | MASTER_PORT_SYMBOL
        | MASTER_LOG_FILE_SYMBOL
        | MASTER_LOG_POS_SYMBOL
        | MASTER_USER_SYMBOL
        | MASTER_PASSWORD_SYMBOL
        | MASTER_PUBLIC_KEY_PATH_SYMBOL // Conditionally set in the lexer.
        | MASTER_SERVER_ID_SYMBOL
        | MASTER_CONNECT_RETRY_SYMBOL
        | MASTER_RETRY_COUNT_SYMBOL
        | MASTER_DELAY_SYMBOL
        | MASTER_SSL_SYMBOL
        | MASTER_SSL_CA_SYMBOL
        | MASTER_SSL_CAPATH_SYMBOL
        | MASTER_TLS_VERSION_SYMBOL     // Conditionally deprecated in the lexer.
        | MASTER_SSL_CERT_SYMBOL
        | MASTER_SSL_CIPHER_SYMBOL
        | MASTER_SSL_CRL_SYMBOL
        | MASTER_SSL_CRLPATH_SYMBOL
        | MASTER_SSL_KEY_SYMBOL
        | MASTER_AUTO_POSITION_SYMBOL
        | MAX_CONNECTIONS_PER_HOUR_SYMBOL
        | MAX_QUERIES_PER_HOUR_SYMBOL
        | MAX_STATEMENT_TIME_SYMBOL     // Conditionally deprecated in the lexer.
        | MAX_SIZE_SYMBOL
        | MAX_UPDATES_PER_HOUR_SYMBOL
        | MAX_USER_CONNECTIONS_SYMBOL
        | MEDIUM_SYMBOL
        | MEMORY_SYMBOL
        | MERGE_SYMBOL
        | MESSAGE_TEXT_SYMBOL
        | MICROSECOND_SYMBOL
        | MIGRATE_SYMBOL
        | MINUTE_SYMBOL
        | MIN_ROWS_SYMBOL
        | MODIFY_SYMBOL
        | MODE_SYMBOL
        | MONTH_SYMBOL
        | MULTILINESTRING_SYMBOL
        | MULTIPOINT_SYMBOL
        | MULTIPOLYGON_SYMBOL
        | MUTEX_SYMBOL
        | MYSQL_ERRNO_SYMBOL
        | NAME_SYMBOL
        | NAMES_SYMBOL
        | NATIONAL_SYMBOL
        | NCHAR_SYMBOL
        | NDBCLUSTER_SYMBOL
        | NESTED_SYMBOL                 // Conditionally set in the lexer.
        | NEVER_SYMBOL
        | NEXT_SYMBOL
        | NEW_SYMBOL
        | NO_WAIT_SYMBOL
        | NODEGROUP_SYMBOL
        | NULLS_SYMBOL                  // Conditionally set in the lexer.
        | NOWAIT_SYMBOL                 // Conditionally deprecated in the lexer.
        | NUMBER_SYMBOL
        | NVARCHAR_SYMBOL
        | OFFSET_SYMBOL
        | OLD_PASSWORD_SYMBOL           // Conditionally deprecated in the lexer.
        | ONE_SHOT_SYMBOL               // Conditionally deprecated in the lexer.
        | ONE_SYMBOL
        | OTHERS_SYMBOL                 // Conditionally set in the lexer.
        | ORDINALITY_SYMBOL             // Conditionally set in the lexer.
        | PACK_KEYS_SYMBOL
        | PAGE_SYMBOL
        | PARTIAL_SYMBOL
        | PARTITIONING_SYMBOL
        | PARTITIONS_SYMBOL
        | PASSWORD_SYMBOL
        | PATH_SYMBOL                   // Conditionally set in the lexer.
        | PHASE_SYMBOL
        | PLUGIN_DIR_SYMBOL
        | PLUGIN_SYMBOL
        | PLUGINS_SYMBOL
        | POINT_SYMBOL
        | POLYGON_SYMBOL
        | PRECEDING_SYMBOL              // Conditionally set in the lexer.
        | PRESERVE_SYMBOL
        | PREV_SYMBOL
        | THREAD_PRIORITY_SYMBOL        // Conditionally set in the lexer.
        | PRIVILEGES_SYMBOL
        | PROCESSLIST_SYMBOL
        | PROFILE_SYMBOL
        | PROFILES_SYMBOL
        | QUARTER_SYMBOL
        | QUERY_SYMBOL
        | QUICK_SYMBOL
        | READ_ONLY_SYMBOL
        | REBUILD_SYMBOL
        | RECOVER_SYMBOL
        | REDO_BUFFER_SIZE_SYMBOL
        | REDOFILE_SYMBOL               // Conditionally set in the lexer.
        | REDUNDANT_SYMBOL
        | RELAY_SYMBOL
        | RELAYLOG_SYMBOL
        | RELAY_LOG_FILE_SYMBOL
        | RELAY_LOG_POS_SYMBOL
        | RELAY_THREAD_SYMBOL
        | REMOTE_SYMBOL                 // Conditionally set in the lexer.
        | REORGANIZE_SYMBOL
        | REPEATABLE_SYMBOL
        | REPLICATE_DO_DB_SYMBOL
        | REPLICATE_IGNORE_DB_SYMBOL
        | REPLICATE_DO_TABLE_SYMBOL
        | REPLICATE_IGNORE_TABLE_SYMBOL
        | REPLICATE_WILD_DO_TABLE_SYMBOL
        | REPLICATE_WILD_IGNORE_TABLE_SYMBOL
        | REPLICATE_REWRITE_DB_SYMBOL
        | USER_RESOURCES_SYMBOL         // Placed like in the server grammar where it is named just RESOURCES.
        | RESPECT_SYMBOL                // Conditionally set in the lexer.
        | RESUME_SYMBOL
        | RETURNED_SQLSTATE_SYMBOL
        | RETURNS_SYMBOL
        | REUSE_SYMBOL                  // Conditionally set in the lexer.
        | REVERSE_SYMBOL
        | ROLLUP_SYMBOL
        | ROTATE_SYMBOL                 // Conditionally deprecated in the lexer.
        | ROUTINE_SYMBOL
        | ROW_COUNT_SYMBOL
        | ROW_FORMAT_SYMBOL
        | RTREE_SYMBOL
        | SCHEDULE_SYMBOL
        | SCHEMA_NAME_SYMBOL
        | SECOND_SYMBOL
        | SERIAL_SYMBOL
        | SERIALIZABLE_SYMBOL
        | SESSION_SYMBOL
        | SHARE_SYMBOL
        | SIMPLE_SYMBOL
        | SKIP_SYMBOL                   // Conditionally set in the lexer.
        | SLOW_SYMBOL
        | SNAPSHOT_SYMBOL
        | SOUNDS_SYMBOL
        | SOURCE_SYMBOL
        | SQL_AFTER_GTIDS_SYMBOL
        | SQL_AFTER_MTS_GAPS_SYMBOL
        | SQL_BEFORE_GTIDS_SYMBOL
        | SQL_CACHE_SYMBOL              // Conditionally deprecated in the lexer.
        | SQL_BUFFER_RESULT_SYMBOL
        | SQL_NO_CACHE_SYMBOL
        | SQL_THREAD_SYMBOL
        | SRID_SYMBOL                   // Conditionally set in the lexer.
        | STACKED_SYMBOL
        | STARTS_SYMBOL
        | STATS_AUTO_RECALC_SYMBOL
        | STATS_PERSISTENT_SYMBOL
        | STATS_SAMPLE_PAGES_SYMBOL
        | STATUS_SYMBOL
        | STORAGE_SYMBOL
        | STRING_SYMBOL
        | SUBCLASS_ORIGIN_SYMBOL
        | SUBDATE_SYMBOL
        | SUBJECT_SYMBOL
        | SUBPARTITION_SYMBOL
        | SUBPARTITIONS_SYMBOL
        | SUPER_SYMBOL
        | SUSPEND_SYMBOL
        | SWAPS_SYMBOL
        | SWITCHES_SYMBOL
        | TABLE_NAME_SYMBOL
        | TABLES_SYMBOL
        | TABLE_CHECKSUM_SYMBOL
        | TABLESPACE_SYMBOL
        | TEMPORARY_SYMBOL
        | TEMPTABLE_SYMBOL
        | TEXT_SYMBOL
        | THAN_SYMBOL
        | TIES_SYMBOL                   // Conditionally set in the lexer.
        | TRANSACTION_SYMBOL
        | TRIGGERS_SYMBOL
        | TIMESTAMP_SYMBOL
        | TIMESTAMP_ADD_SYMBOL
        | TIMESTAMP_DIFF_SYMBOL
        | TIME_SYMBOL
        | TYPES_SYMBOL
        | TYPE_SYMBOL
        | UDF_RETURNS_SYMBOL
        | UNBOUNDED_SYMBOL              // Conditionally set in the lexer.
        | UNCOMMITTED_SYMBOL
        | UNDEFINED_SYMBOL
        | UNDO_BUFFER_SIZE_SYMBOL
        | UNDOFILE_SYMBOL
        | UNKNOWN_SYMBOL
        | UNTIL_SYMBOL
        | USER_SYMBOL
        | USE_FRM_SYMBOL
        | VARIABLES_SYMBOL
        | VCPU_SYMBOL                   // Conditionally set in the lexer.
        | VIEW_SYMBOL
        | VALUE_SYMBOL
        | WARNINGS_SYMBOL
        | WAIT_SYMBOL
        | WEEK_SYMBOL
        | WORK_SYMBOL
        | WEIGHT_STRING_SYMBOL
        | X509_SYMBOL
        | XID_SYMBOL
        | XML_SYMBOL
        | YEAR_SYMBOL
    )
    // Tokens that entered or left this rule in specific versions and are not automatically
    // handled in the lexer.
    | {serverVersion < 50709}? SHUTDOWN_SYMBOL
    | {serverVersion < 80000}? (
        CUBE_SYMBOL
        | IMPORT_SYMBOL
        | FUNCTION_SYMBOL
        | ROWS_SYMBOL
        | ROW_SYMBOL
    )
    | {serverVersion >= 80000}? (
        EXCHANGE_SYMBOL
        | EXPIRE_SYMBOL
        | ONLY_SYMBOL
        | SUPER_SYMBOL
        | VALIDATION_SYMBOL
        | WITHOUT_SYMBOL
    )
;

// Non-reserved keywords that we allow for role names.
//
//  In order not to introduce new grammar conflicts, the following keyword tokens are
//  not welcome as role names:
//
//    EVENT_SYM
//    EXECUTE_SYM
//    FILE_SYM
//    PROCESS
//    PROXY_SYM
//    RELOAD
//    REPLICATION
//    RESOURCE_SYM
//    RESTART_SYM
//    SHUTDOWN
//    SUPER_SYM
roleKeyword:
    roleOrLabelKeyword
    | roleOrIdentifierKeyword
;
