using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class InitialBackendSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "NGC_AgentGroups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExternalId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_AgentGroups", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "NGC_Queues",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExternalId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_Queues", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "NGC_Site",
                columns: table => new
                {
                    SiteId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    SiteName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    TimeZone = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true),
                    ClearTime = table.Column<string>(type: "character varying(5)", maxLength: 5, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_Site", x => x.SiteId);
                });

            migrationBuilder.CreateTable(
                name: "NGC_Supergroup",
                columns: table => new
                {
                    SupergroupId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    SupergroupName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    SupergroupIdOld = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_Supergroup", x => x.SupergroupId);
                });

            migrationBuilder.CreateTable(
                name: "RTSGrid_Metric",
                columns: table => new
                {
                    MetricId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "text", nullable: true),
                    DataType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    MetricFunction = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    MetricParameter = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    MetricFormat = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    DefaultValue = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ValueType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "String"),
                    MetricType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "Agent")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_Metric", x => x.MetricId);
                });

            migrationBuilder.CreateTable(
                name: "RTSUserGrid_Column",
                columns: table => new
                {
                    ColumnId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    ColumnsSetId = table.Column<int>(type: "integer", nullable: false),
                    Title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    MetricId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    ColumnsOrder = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSUserGrid_Column", x => x.ColumnId);
                });

            migrationBuilder.CreateTable(
                name: "RTSUserGrid_ColumnsSet",
                columns: table => new
                {
                    ColumnsSetId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    Title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "text", nullable: true),
                    Direction = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSUserGrid_ColumnsSet", x => x.ColumnsSetId);
                });

            migrationBuilder.CreateTable(
                name: "RTSUserGrid_Grid",
                columns: table => new
                {
                    GridId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    UnionId = table.Column<int>(type: "integer", nullable: true),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    Title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    RowsFilter = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    PageSize = table.Column<int>(type: "integer", nullable: true),
                    ColumnsSetId = table.Column<int>(type: "integer", nullable: true),
                    ThresholdScript = table.Column<string>(type: "text", nullable: true),
                    RowsFilterNew = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    NoRecordsText = table.Column<string>(type: "text", nullable: true),
                    AllowPaging = table.Column<bool>(type: "boolean", nullable: true),
                    AllowScroll = table.Column<bool>(type: "boolean", nullable: true),
                    TextDirection = table.Column<string>(type: "character varying(5)", maxLength: 5, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSUserGrid_Grid", x => x.GridId);
                });

            migrationBuilder.CreateTable(
                name: "NGC_BusinessUnit",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    BusinessUnitName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Description = table.Column<string>(type: "text", nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    SiteId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_BusinessUnit", x => x.BusinessUnitId);
                    table.ForeignKey(
                        name: "FK_NGC_BusinessUnit_NGC_Site_SiteId",
                        column: x => x.SiteId,
                        principalTable: "NGC_Site",
                        principalColumn: "SiteId",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "NGC_SupergroupAgentgroup",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    SupergroupId = table.Column<int>(type: "integer", nullable: true),
                    AgentgroupId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_SupergroupAgentgroup", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NGC_SupergroupAgentgroup_NGC_Supergroup_SupergroupId",
                        column: x => x.SupergroupId,
                        principalTable: "NGC_Supergroup",
                        principalColumn: "SupergroupId");
                });

            migrationBuilder.CreateTable(
                name: "NGC_BusinessUnitQueueClassification",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false),
                    QueueId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClassificationId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_BusinessUnitQueueClassification", x => new { x.BusinessUnitId, x.QueueId });
                    table.ForeignKey(
                        name: "FK_NGC_BusinessUnitQueueClassification_NGC_BusinessUnit_Busine~",
                        column: x => x.BusinessUnitId,
                        principalTable: "NGC_BusinessUnit",
                        principalColumn: "BusinessUnitId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "NGC_BusinessUnitSupergroup",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false),
                    SupergroupId = table.Column<int>(type: "integer", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_BusinessUnitSupergroup", x => new { x.BusinessUnitId, x.SupergroupId });
                    table.ForeignKey(
                        name: "FK_NGC_BusinessUnitSupergroup_NGC_BusinessUnit_BusinessUnitId",
                        column: x => x.BusinessUnitId,
                        principalTable: "NGC_BusinessUnit",
                        principalColumn: "BusinessUnitId",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_NGC_BusinessUnitSupergroup_NGC_Supergroup_SupergroupId",
                        column: x => x.SupergroupId,
                        principalTable: "NGC_Supergroup",
                        principalColumn: "SupergroupId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_NGC_BusinessUnit_SiteId",
                table: "NGC_BusinessUnit",
                column: "SiteId");

            migrationBuilder.CreateIndex(
                name: "IX_NGC_BusinessUnitSupergroup_SupergroupId",
                table: "NGC_BusinessUnitSupergroup",
                column: "SupergroupId");

            migrationBuilder.CreateIndex(
                name: "IX_NGC_SupergroupAgentgroup_SupergroupId",
                table: "NGC_SupergroupAgentgroup",
                column: "SupergroupId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "NGC_AgentGroups");

            migrationBuilder.DropTable(
                name: "NGC_BusinessUnitQueueClassification");

            migrationBuilder.DropTable(
                name: "NGC_BusinessUnitSupergroup");

            migrationBuilder.DropTable(
                name: "NGC_Queues");

            migrationBuilder.DropTable(
                name: "NGC_SupergroupAgentgroup");

            migrationBuilder.DropTable(
                name: "RTSGrid_Metric");

            migrationBuilder.DropTable(
                name: "RTSUserGrid_Column");

            migrationBuilder.DropTable(
                name: "RTSUserGrid_ColumnsSet");

            migrationBuilder.DropTable(
                name: "RTSUserGrid_Grid");

            migrationBuilder.DropTable(
                name: "NGC_BusinessUnit");

            migrationBuilder.DropTable(
                name: "NGC_Supergroup");

            migrationBuilder.DropTable(
                name: "NGC_Site");
        }
    }
}
