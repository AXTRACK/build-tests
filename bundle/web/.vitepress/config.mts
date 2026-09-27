import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid(
  defineConfig({
    lang: 'en-US',
    title: 'Technical Architect KB',
    titleTemplate: ':title · Technical Architect KB',
    description:
      'Decision-oriented knowledge base for Technical and Solution Architecture.',
    srcDir: '.generated/publication',
    cleanUrls: true,
    rewrites: {
      'README.md': 'index.md',
      'showcase/README.md': 'showcase/index.md',
      'knowledge/README.md': 'knowledge/index.md',
      'examples/README.md': 'examples/index.md',
      'templates/README.md': 'templates/index.md'
    },
    themeConfig: {
      siteTitle: 'Technical Architect KB',
      search: {
        provider: 'local'
      },
      nav: [
        {
          text: 'Start',
          items: [
            { text: 'Guided Tour', link: '/showcase/' },
            { text: 'Decision Router', link: '/knowledge/decision-router' }
          ]
        },
        {
          text: 'Explore',
          items: [
            { text: 'Knowledge Domains', link: '/knowledge/domains' },
            { text: 'Topics', link: '/knowledge/topics' },
            { text: 'Reading Paths', link: '/knowledge/reading-paths' },
            { text: 'Glossary', link: '/knowledge/glossary' }
          ]
        },
        {
          text: 'Apply',
          items: [
            { text: 'Worked Examples', link: '/examples/' },
            { text: 'Templates', link: '/templates/' }
          ]
        },
        { text: 'About', link: '/ABOUT' }
      ],
      sidebar: [
        {
          text: 'Start',
          items: [
            { text: 'Home', link: '/' },
            { text: 'Guided Tour', link: '/showcase/' },
            { text: 'Decision Router', link: '/knowledge/decision-router' }
          ]
        },
        {
          text: 'Explore',
          items: [
            { text: 'Knowledge Domains', link: '/knowledge/domains' },
            { text: 'Topics', link: '/knowledge/topics' },
            { text: 'Reading Paths', link: '/knowledge/reading-paths' },
            { text: 'Glossary', link: '/knowledge/glossary' }
          ]
        },
        {
          text: 'Domains',
          collapsed: true,
          items: [
            { text: 'Role', link: '/knowledge/domains#role' },
            { text: 'Architecture', link: '/knowledge/domains#architecture' },
            { text: 'Solutioning', link: '/knowledge/domains#solutioning' },
            { text: 'Governance', link: '/knowledge/domains#governance' },
            { text: 'Engineering', link: '/knowledge/domains#engineering' },
            { text: 'Environments', link: '/knowledge/domains#environments' },
            { text: 'AI', link: '/knowledge/domains#ai' }
          ]
        },
        {
          text: 'Apply',
          items: [
            { text: 'Worked Examples', link: '/examples/' },
            { text: 'Templates', link: '/templates/' }
          ]
        },
        {
          text: 'About',
          items: [{ text: 'About this KB', link: '/ABOUT' }]
        }
      ],
      outline: {
        level: [2, 3],
        label: 'On this page'
      },
      docFooter: {
        prev: 'Previous',
        next: 'Next'
      },
      returnToTopLabel: 'Back to top',
      sidebarMenuLabel: 'Menu',
      darkModeSwitchLabel: 'Theme',
      lightModeSwitchTitle: 'Use light theme',
      darkModeSwitchTitle: 'Use dark theme'
    },
    markdown: {
      lineNumbers: false
    },
    mermaid: {
      securityLevel: 'strict'
    }
  })
)
