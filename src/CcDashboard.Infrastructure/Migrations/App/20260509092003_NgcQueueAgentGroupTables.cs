using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class NgcQueueAgentGroupTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "agent_supergroups");

            migrationBuilder.DropTable(
                name: "business_units");

            migrationBuilder.DropTable(
                name: "ngc_business_unit_queue");

            migrationBuilder.DropTable(
                name: "ngc_business_unit_supergroup");

            migrationBuilder.DropTable(
                name: "ngc_supergroup_agent_group");

            migrationBuilder.DropTable(
                name: "pg_agent_supergroups");

            migrationBuilder.DropTable(
                name: "queues");

            migrationBuilder.DropTable(
                name: "skills");

            migrationBuilder.DropTable(
                name: "ngc_queue");

            migrationBuilder.DropTable(
                name: "ngc_business_unit");

            migrationBuilder.DropTable(
                name: "ngc_agent_group");

            migrationBuilder.DropPrimaryKey(
                name: "PK_pg_business_units",
                table: "pg_business_units");

            migrationBuilder.DropPrimaryKey(
                name: "PK_ngc_supergroup",
                table: "ngc_supergroup");

            migrationBuilder.DropPrimaryKey(
                name: "PK_ngc_site",
                table: "ngc_site");

            migrationBuilder.DropColumn(
                name: "ObjectId",
                table: "pg_business_units");

            migrationBuilder.RenameTable(
                name: "ngc_supergroup",
                newName: "NGC_Supergroup");

            migrationBuilder.RenameTable(
                name: "ngc_site",
                newName: "NGC_Site");

            migrationBuilder.AddColumn<int>(
                name: "BusinessUnitId",
                table: "pg_business_units",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AlterColumn<string>(
                name: "CreatedBy",
                table: "NGC_Supergroup",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(200)",
                oldMaxLength: 200,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "SiteId",
                table: "NGC_Site",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(100)",
                oldMaxLength: 100);

            migrationBuilder.AddPrimaryKey(
                name: "PK_pg_business_units",
                table: "pg_business_units",
                columns: new[] { "PermissionGroupId", "BusinessUnitId" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_NGC_Supergroup",
                table: "NGC_Supergroup",
                column: "SupergroupId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_NGC_Site",
                table: "NGC_Site",
                column: "SiteId");

            migrationBuilder.CreateTable(
                name: "ngc_AgentGroups",
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
                    table.PrimaryKey("PK_ngc_AgentGroups", x => x.Id);
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
                name: "ngc_queues",
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
                    table.PrimaryKey("PK_ngc_queues", x => x.Id);
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
                name: "pg_supergroups",
                columns: table => new
                {
                    PermissionGroupId = table.Column<Guid>(type: "uuid", nullable: false),
                    SupergroupId = table.Column<int>(type: "integer", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_pg_supergroups", x => new { x.PermissionGroupId, x.SupergroupId });
                    table.ForeignKey(
                        name: "FK_pg_supergroups_permission_groups_PermissionGroupId",
                        column: x => x.PermissionGroupId,
                        principalTable: "permission_groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
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
                name: "ngc_AgentGroups");

            migrationBuilder.DropTable(
                name: "NGC_BusinessUnitQueueClassification");

            migrationBuilder.DropTable(
                name: "NGC_BusinessUnitSupergroup");

            migrationBuilder.DropTable(
                name: "ngc_queues");

            migrationBuilder.DropTable(
                name: "NGC_SupergroupAgentgroup");

            migrationBuilder.DropTable(
                name: "pg_supergroups");

            migrationBuilder.DropTable(
                name: "NGC_BusinessUnit");

            migrationBuilder.DropPrimaryKey(
                name: "PK_pg_business_units",
                table: "pg_business_units");

            migrationBuilder.DropPrimaryKey(
                name: "PK_NGC_Supergroup",
                table: "NGC_Supergroup");

            migrationBuilder.DropPrimaryKey(
                name: "PK_NGC_Site",
                table: "NGC_Site");

            migrationBuilder.DropColumn(
                name: "BusinessUnitId",
                table: "pg_business_units");

            migrationBuilder.RenameTable(
                name: "NGC_Supergroup",
                newName: "ngc_supergroup");

            migrationBuilder.RenameTable(
                name: "NGC_Site",
                newName: "ngc_site");

            migrationBuilder.AddColumn<Guid>(
                name: "ObjectId",
                table: "pg_business_units",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AlterColumn<string>(
                name: "CreatedBy",
                table: "ngc_supergroup",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(100)",
                oldMaxLength: 100,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "SiteId",
                table: "ngc_site",
                type: "character varying(100)",
                maxLength: 100,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(50)",
                oldMaxLength: 50);

            migrationBuilder.AddPrimaryKey(
                name: "PK_pg_business_units",
                table: "pg_business_units",
                columns: new[] { "PermissionGroupId", "ObjectId" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_ngc_supergroup",
                table: "ngc_supergroup",
                column: "SupergroupId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_ngc_site",
                table: "ngc_site",
                column: "SiteId");

            migrationBuilder.CreateTable(
                name: "agent_supergroups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ExternalId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_agent_supergroups", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "business_units",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ExternalId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_business_units", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ngc_agent_group",
                columns: table => new
                {
                    AgentGroupId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_agent_group", x => x.AgentGroupId);
                });

            migrationBuilder.CreateTable(
                name: "ngc_business_unit",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    SiteId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    BusinessUnitName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
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
                name: "ngc_queue",
                columns: table => new
                {
                    QueueId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ngc_queue", x => x.QueueId);
                });

            migrationBuilder.CreateTable(
                name: "pg_agent_supergroups",
                columns: table => new
                {
                    PermissionGroupId = table.Column<Guid>(type: "uuid", nullable: false),
                    ObjectId = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_pg_agent_supergroups", x => new { x.PermissionGroupId, x.ObjectId });
                    table.ForeignKey(
                        name: "FK_pg_agent_supergroups_permission_groups_PermissionGroupId",
                        column: x => x.PermissionGroupId,
                        principalTable: "permission_groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "queues",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ExternalId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_queues", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "skills",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ExternalId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_skills", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ngc_supergroup_agent_group",
                columns: table => new
                {
                    SupergroupId = table.Column<int>(type: "integer", nullable: false),
                    AgentGroupId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
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
                name: "ngc_business_unit_supergroup",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false),
                    SupergroupId = table.Column<int>(type: "integer", nullable: false),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
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

            migrationBuilder.CreateTable(
                name: "ngc_business_unit_queue",
                columns: table => new
                {
                    BusinessUnitId = table.Column<int>(type: "integer", nullable: false),
                    QueueId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ClassificationId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
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
    }
}
