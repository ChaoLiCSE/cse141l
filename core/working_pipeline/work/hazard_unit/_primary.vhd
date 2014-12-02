library verilog;
use verilog.vl_types.all;
library work;
entity hazard_unit is
    port(
        clk             : in     vl_logic;
        jump_now        : in     vl_logic;
        fd_pipeline_r   : in     work.hazard_unit_sv_unit.fd_pipeline_s;
        control_pipeline: in     work.hazard_unit_sv_unit.control_pipeline_s;
        dx_pipeline_r   : in     work.hazard_unit_sv_unit.dx_pipeline_s;
        xm_pipeline_r   : in     work.hazard_unit_sv_unit.xm_pipeline_s;
        mw_pipeline_r   : in     work.hazard_unit_sv_unit.mw_pipeline_s;
        bubble          : out    vl_logic;
        forwardA        : out    vl_logic_vector(1 downto 0);
        forwardB        : out    vl_logic_vector(1 downto 0)
    );
end hazard_unit;
