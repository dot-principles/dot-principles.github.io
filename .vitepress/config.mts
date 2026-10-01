import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid(
  defineConfig({
    title: '.principles',
    description: 'Plain-text engineering principles for AI coding agents',
    srcDir: 'content',
    themeConfig: {
      nav: [
        { text: 'Home', link: '/' },
        { text: 'Why', link: '/why' },
        { text: 'Getting Started', link: '/getting-started' },
        { text: 'How It Works', link: '/how-it-works' },
        { text: 'Commands', link: '/commands' },
        { text: 'Extending', link: '/extending' },
        { text: 'Governance', link: '/governance' },
      ],
      sidebar: [
        { text: 'Overview', link: '/' },
        { text: 'Why `.principles`', link: '/why' },
        { text: 'Examples and Demo', link: '/examples' },
        { text: 'Getting Started', link: '/getting-started' },
        { text: 'Command Workflow', link: '/commands' },
        { text: 'How It Works', link: '/how-it-works' },
        { text: 'Extending the Catalog', link: '/extending' },
        { text: 'Governance', link: '/governance' },
      ],
    },
  })
)