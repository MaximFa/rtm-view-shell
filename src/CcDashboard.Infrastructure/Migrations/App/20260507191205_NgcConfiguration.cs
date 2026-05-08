using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class NgcConfiguration : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ngc_agent_group",
                columns: table => new
                {
                    AgentGroupId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_agent_group", x => x.AgentGroupId);
                });

            migrationBuilder.CreateTable(
                name: "ngc_queue",
                columns: table => new
                {
                    QueueId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_queue", x => x.QueueId);
                });

            migrationBuilder.CreateTable(
                name: "ngc_site",
                columns: table => new
                {
                    SiteId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    SiteName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    TimeZone = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true),
                    ClearTime = table.Column<string>(type: "character varying(5)", maxLength: 5, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_site", x => x.SiteId);
                });

            migrationBuilder.CreateTable(
                name: "ngc_supergroup",
                columns: table => new
                {
                    SupergroupId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    SupergroupName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    SupergroupIdOld = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_supergroup", x => x.SupergroupId);
                });

            migrationBuilder.CreateTable(
                name: "rtsgrid_metric",
                columns: table => new
                {
                    MetricId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Description = table.Column<string>(type: "text", nullable: true),
                    DataType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    MetricFunction = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    MetricParameter = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    MetricFormat = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    DefaultValue = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_rtsgrid_metric", x => x.MetricId);
                });

            migrationBuilder.CreateTable(
                name: "ngc_business_unit",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    BusinessUnitName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    SiteId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_business_unit", x => x.BusinessUnitId);
                    table.ForeignKey(
                        name: "FK_ngc_business_unit_ngc_site_SiteId",
                        column: x => x.SiteId,
                        principalTable: "ngc_site",
                        principalColumn: "SiteId",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "ngc_supergroup_agent_group",
                columns: table => new
                {
                    SupergroupId = table.Column<int>(type: "integer", nullable: false),
                    AgentGroupId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_supergroup_agent_group", x => new { x.SupergroupId, x.AgentGroupId });
                    table.ForeignKey(
                        name: "FK_ngc_supergroup_agent_group_ngc_agent_group_AgentGroupId",
                        column: x => x.AgentGroupId,
                        principalTable: "ngc_agent_group",
                        principalColumn: "AgentGroupId",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ngc_supergroup_agent_group_ngc_supergroup_SupergroupId",
                        column: x => x.SupergroupId,
                        principalTable: "ngc_supergroup",
                        principalColumn: "SupergroupId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ngc_business_unit_queue",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false),
                    QueueId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClassificationId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_business_unit_queue", x => new { x.BusinessUnitId, x.QueueId });
                    table.ForeignKey(
                        name: "FK_ngc_business_unit_queue_ngc_business_unit_BusinessUnitId",
                        column: x => x.BusinessUnitId,
                        principalTable: "ngc_business_unit",
                        principalColumn: "BusinessUnitId",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ngc_business_unit_queue_ngc_queue_QueueId",
                        column: x => x.QueueId,
                        principalTable: "ngc_queue",
                        principalColumn: "QueueId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ngc_business_unit_supergroup",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false),
                    SupergroupId = table.Column<int>(type: "integer", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_business_unit_supergroup", x => new { x.BusinessUnitId, x.SupergroupId });
                    table.ForeignKey(
                        name: "FK_ngc_business_unit_supergroup_ngc_business_unit_BusinessUnit~",
                        column: x => x.BusinessUnitId,
                        principalTable: "ngc_business_unit",
                        principalColumn: "BusinessUnitId",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ngc_business_unit_supergroup_ngc_supergroup_SupergroupId",
                        column: x => x.SupergroupId,
                        principalTable: "ngc_supergroup",
                        principalColumn: "SupergroupId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ngc_business_unit_SiteId",
                table: "ngc_business_unit",
                column: "SiteId");

            migrationBuilder.CreateIndex(
                name: "IX_ngc_business_unit_queue_QueueId",
                table: "ngc_business_unit_queue",
                column: "QueueId");

            migrationBuilder.CreateIndex(
                name: "IX_ngc_business_unit_supergroup_SupergroupId",
                table: "ngc_business_unit_supergroup",
                column: "SupergroupId");

            migrationBuilder.CreateIndex(
                name: "IX_ngc_supergroup_agent_group_AgentGroupId",
                table: "ngc_supergroup_agent_group",
                column: "AgentGroupId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ngc_business_unit_queue");

            migrationBuilder.DropTable(
                name: "ngc_business_unit_supergroup");

            migrationBuilder.DropTable(
                name: "ngc_supergroup_agent_group");

            migrationBuilder.DropTable(
                name: "rtsgrid_metric");

            migrationBuilder.DropTable(
                name: "ngc_queue");

            migrationBuilder.DropTable(
                name: "ngc_business_unit");

            migrationBuilder.DropTable(
                name: "ngc_agent_group");

            migrationBuilder.DropTable(
                name: "ngc_supergroup");

            migrationBuilder.DropTable(
                name: "ngc_site");
        }
    }
}
