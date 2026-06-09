-- Migration 022: add 'ai_agent' to the flow_nodes.node_type CHECK constraint.
--
-- The constraint was last touched in 016_flow_media.sql (added 'send_media').
-- We follow the same DROP + re-ADD pattern used there.

ALTER TABLE flow_nodes
  DROP CONSTRAINT IF EXISTS flow_nodes_node_type_check;

ALTER TABLE flow_nodes
  ADD CONSTRAINT flow_nodes_node_type_check
  CHECK (node_type IN (
    'start',
    'send_buttons',
    'send_list',
    'send_message',
    'send_media',
    'collect_input',
    'condition',
    'set_tag',
    'ai_agent',
    'handoff',
    'http_fetch',
    'end'
  ));
