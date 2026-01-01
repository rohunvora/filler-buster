import './globals.css'

export const metadata = {
  title: 'Filler Counter',
  description: 'Count your filler words. Speak cleaner.',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
