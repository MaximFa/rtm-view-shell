using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class AddAgentStateRegistry : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "tenant_agent_state_groups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    GroupName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_tenant_agent_state_groups", x => x.Id);
                    table.ForeignKey(
                        name: "FK_tenant_agent_state_groups_tenants_TenantId",
                        column: x => x.TenantId,
                        principalTable: "tenants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "tenant_agent_states",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    AgentState = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_tenant_agent_states", x => x.Id);
                    table.ForeignKey(
                        name: "FK_tenant_agent_states_tenants_TenantId",
                        column: x => x.TenantId,
                        principalTable: "tenants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "tenant_agent_state_definitions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    AgentStateId = table.Column<Guid>(type: "uuid", nullable: false),
                    AgentStateGroupId = table.Column<Guid>(type: "uuid", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_tenant_agent_state_definitions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_tenant_agent_state_definitions_tenant_agent_state_groups_Ag~",
                        column: x => x.AgentStateGroupId,
                        principalTable: "tenant_agent_state_groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_tenant_agent_state_definitions_tenant_agent_states_AgentSta~",
                        column: x => x.AgentStateId,
                        principalTable: "tenant_agent_states",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_tenant_agent_state_definitions_AgentStateGroupId",
                table: "tenant_agent_state_definitions",
                column: "AgentStateGroupId");

            migrationBuilder.CreateIndex(
                name: "IX_tenant_agent_state_definitions_AgentStateId",
                table: "tenant_agent_state_definitions",
                column: "AgentStateId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_tenant_agent_state_definitions_TenantId_AgentStateId",
                table: "tenant_agent_state_definitions",
                columns: new[] { "TenantId", "AgentStateId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_tenant_agent_state_groups_TenantId_GroupName",
                table: "tenant_agent_state_groups",
                columns: new[] { "TenantId", "GroupName" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_tenant_agent_states_TenantId_AgentState",
                table: "tenant_agent_states",
                columns: new[] { "TenantId", "AgentState" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "tenant_agent_state_definitions");

            migrationBuilder.DropTable(
                name: "tenant_agent_state_groups");

            migrationBuilder.DropTable(
                name: "tenant_agent_states");
        }
    }
}
