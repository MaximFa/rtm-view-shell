using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddQueueGridTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Use IF NOT EXISTS to handle databases where tables may already exist
            // from AppDbContext migrations or previous runs.
            migrationBuilder.Sql(@"
                CREATE TABLE IF NOT EXISTS ""RTSGrid_Grid"" (
                    ""GridId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""UnionId"" integer,
                    ""StyleId"" integer,
                    ""Title"" character varying(100) NOT NULL,
                    ""ThresholdScript"" text,
                    CONSTRAINT ""PK_RTSGrid_Grid"" PRIMARY KEY (""GridId"")
                );

                CREATE TABLE IF NOT EXISTS ""RTSGrid_Column"" (
                    ""ColumnId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""GridId"" integer NOT NULL,
                    ""ColumnNumber"" integer NOT NULL,
                    ""CellTemplateId"" integer,
                    CONSTRAINT ""PK_RTSGrid_Column"" PRIMARY KEY (""ColumnId"")
                );

                CREATE TABLE IF NOT EXISTS ""RTSGrid_Row"" (
                    ""RowId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""GridId"" integer NOT NULL,
                    ""RowNumber"" integer NOT NULL,
                    ""UnionId"" integer,
                    ""StyleId"" integer,
                    ""ThresholdScript"" text,
                    ""OldRowId"" integer,
                    CONSTRAINT ""PK_RTSGrid_Row"" PRIMARY KEY (""RowId"")
                );

                CREATE TABLE IF NOT EXISTS ""RTSGrid_Cell"" (
                    ""CellId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""RowId"" integer NOT NULL,
                    ""ColumnId"" integer NOT NULL,
                    ""ColNumber"" integer,
                    ""UnionId"" integer,
                    ""StyleId"" integer,
                    ""CellType"" character varying(50),
                    ""Value"" character varying(500),
                    ""Tooltip"" character varying(500),
                    ""OnClick"" character varying(500),
                    ""ThresholdSetId"" integer,
                    ""NewRowId"" integer,
                    ""OldRowId"" integer,
                    CONSTRAINT ""PK_RTSGrid_Cell"" PRIMARY KEY (""CellId"")
                );
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                DROP TABLE IF EXISTS ""RTSGrid_Cell"";
                DROP TABLE IF EXISTS ""RTSGrid_Row"";
                DROP TABLE IF EXISTS ""RTSGrid_Column"";
                DROP TABLE IF EXISTS ""RTSGrid_Grid"";
            ");
        }
    }
}
