using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddMissingRtmTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RTSData_ChatMessage",
                columns: table => new
                {
                    MessageId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ServerId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    OnDate = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    InteractionId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    SegmentId = table.Column<int>(type: "integer", nullable: true),
                    UserId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    MsgDirection = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Sender = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Recipient = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Body = table.Column<string>(type: "text", nullable: true),
                    DeliveryStatus = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    UpdateTime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    TimeStamp = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSData_ChatMessage", x => new { x.MessageId, x.ServerId, x.OnDate });
                });

            migrationBuilder.CreateTable(
                name: "RTSGrid_Statistic",
                columns: table => new
                {
                    StatisticId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Category = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Definition = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType1 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue1 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType2 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue2 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType3 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue3 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType4 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue4 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType5 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue5 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType6 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue6 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType7 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue7 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType8 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue8 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType9 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue9 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ParamType10 = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ParamValue10 = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_Statistic", x => x.StatisticId);
                });

            migrationBuilder.CreateTable(
                name: "RTSGrid_TemplateCell",
                columns: table => new
                {
                    CellTemplateId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    CellType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Value = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Tooltip = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    OnClick = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_TemplateCell", x => x.CellTemplateId);
                });

            migrationBuilder.CreateTable(
                name: "RTSGrid_UserStatus",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    StatusId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    StatusName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    StatusGroup = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    TotalDuration = table.Column<int>(type: "integer", nullable: true),
                    MaxDuraction = table.Column<int>(type: "integer", nullable: true),
                    TotalCount = table.Column<int>(type: "integer", nullable: true),
                    SourceServer = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    OnDate = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_UserStatus", x => new { x.UserId, x.StatusId });
                });

            migrationBuilder.CreateIndex(
                name: "IX_RTSData_Interaction_UpsertKey",
                table: "RTSData_Interaction",
                columns: new[] { "InteractionId", "Segment", "ServerId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RTSData_ChatMessage_MessageId_ServerId",
                table: "RTSData_ChatMessage",
                columns: new[] { "MessageId", "ServerId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RTSData_ChatMessage");

            migrationBuilder.DropTable(
                name: "RTSGrid_Statistic");

            migrationBuilder.DropTable(
                name: "RTSGrid_TemplateCell");

            migrationBuilder.DropTable(
                name: "RTSGrid_UserStatus");

            migrationBuilder.DropIndex(
                name: "IX_RTSData_Interaction_UpsertKey",
                table: "RTSData_Interaction");
        }
    }
}
