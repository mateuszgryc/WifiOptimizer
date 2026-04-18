import { PanelSection, PanelSectionRow } from "@decky/ui";
import { theme } from "../theme";

interface PanelFooterProps {
  version: string;
}

// Bottom-of-panel version tag and support pointer.
export function PanelFooter({ version }: PanelFooterProps) {
  const rowStyle: React.CSSProperties = {
    fontSize: theme.fontSize.tiny,
    color: theme.text.dim,
  };
  return (
    <PanelSection>
      <PanelSectionRow>
        <div style={rowStyle}>v{version} - by jasonridesabike</div>
      </PanelSectionRow>
      <PanelSectionRow>
        <div style={rowStyle}>
          If WiFi won't reconnect, a reboot usually fixes it.
          <br />
          Hardened fork: github.com/mateuszgryc/WifiOptimizer
        </div>
      </PanelSectionRow>
    </PanelSection>
  );
}
